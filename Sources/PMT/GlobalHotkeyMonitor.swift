import AppKit

private final class HotkeyRuntimeState: @unchecked Sendable {
    private let lock = NSLock()
    private var bindings: [HotkeyBinding] = []
    private var chordArmedUntil: Date?
    private var armedBinding: HotkeyBinding?
    private let chordTimeout: TimeInterval = 1.2

    func updateBindings(_ bindings: [HotkeyBinding]) {
        lock.lock()
        self.bindings = bindings
        chordArmedUntil = nil
        armedBinding = nil
        lock.unlock()
    }

    func handle(keyCode: UInt16, flags: CGEventFlags) -> HotkeyEvent {
        lock.lock()
        defer { lock.unlock() }

        if let chordArmedUntil {
            guard Date() <= chordArmedUntil, let armedBinding else {
                self.chordArmedUntil = nil
                self.armedBinding = nil
                return .expired
            }

            if armedBinding.hotkey.matchesSecondary(keyCode: keyCode) {
                self.chordArmedUntil = nil
                self.armedBinding = nil
                return .trigger(armedBinding)
            }

            self.chordArmedUntil = nil
            self.armedBinding = nil
            return .secondaryMismatch(HotkeyConfig.keyName(for: keyCode))
        }

        for binding in bindings where binding.hotkey.matches(keyCode: keyCode, flags: flags) {
            if let secondaryKeyCode = binding.hotkey.secondaryKeyCode {
                chordArmedUntil = Date().addingTimeInterval(chordTimeout)
                armedBinding = binding
                return .armed(
                    firstKeyName: HotkeyConfig.keyName(for: keyCode),
                    secondKeyName: HotkeyConfig.keyName(for: secondaryKeyCode)
                )
            }
            return .trigger(binding)
        }

        return .none
    }
}

private struct HotkeyBinding {
    let action: HotkeyAction
    let hotkey: HotkeyConfig
}

private enum HotkeyAction {
    case rewrite
    case dictation
}

private enum HotkeyEvent {
    case none
    case armed(firstKeyName: String, secondKeyName: String)
    case trigger(HotkeyBinding)
    case secondaryMismatch(String)
    case expired
}

@MainActor
final class GlobalHotkeyMonitor {
    private let store: ConfigStore
    private let onRewriteTrigger: (NSRunningApplication?) -> Void
    private let onDictationTrigger: (NSRunningApplication?) -> Void
    private let eventTapState = HotkeyRuntimeState()
    private let nsEventState = HotkeyRuntimeState()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(
        store: ConfigStore,
        onRewriteTrigger: @escaping (NSRunningApplication?) -> Void,
        onDictationTrigger: @escaping (NSRunningApplication?) -> Void
    ) {
        self.store = store
        self.onRewriteTrigger = onRewriteTrigger
        self.onDictationTrigger = onDictationTrigger
    }

    func start() {
        stop()
        let bindings = currentBindings()
        eventTapState.updateBindings(bindings)
        nsEventState.updateBindings(bindings)
        store.addLog("启动全局热键监听：\(bindings.map { $0.hotkey.displayName }.joined(separator: ", "))")
        store.addLog("键盘权限状态：\(PermissionManager.keyboardPermissionSummary(language: store.language))")

        let mask = (1 << CGEventType.keyDown.rawValue)
        let unmanagedSelf = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    Task { @MainActor in
                        monitor.store.addLog("全局热键监听被系统暂停，已尝试重新启用")
                        if let eventTap = monitor.eventTap {
                            CGEvent.tapEnable(tap: eventTap, enable: true)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard type == .keyDown else {
                    return Unmanaged.passUnretained(event)
                }

                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let flags = event.flags
                let hotkeyEvent = monitor.eventTapState.handle(keyCode: keyCode, flags: flags)

                switch hotkeyEvent {
                case .none:
                    return Unmanaged.passUnretained(event)
                case .armed(let firstKeyName, let secondKeyName):
                    Task { @MainActor in
                        monitor.store.addLog("CGEventTap 收到前导键：\(firstKeyName)，等待 \(secondKeyName)")
                    }
                    return nil
                case .trigger(let binding):
                    Task { @MainActor in
                        monitor.store.addLog("CGEventTap 收到完整快捷键：\(binding.hotkey.displayName)")
                        monitor.trigger(binding.action, targetApplication: NSWorkspace.shared.frontmostApplication)
                    }
                    return nil
                case .secondaryMismatch(let keyName):
                    Task { @MainActor in
                        monitor.store.addLog("CGEventTap 第二键不匹配：收到 \(keyName)")
                    }
                    return Unmanaged.passUnretained(event)
                case .expired:
                    Task { @MainActor in
                        monitor.store.addLog("CGEventTap 快捷键等待超时")
                    }
                    return Unmanaged.passUnretained(event)
                }
            },
            userInfo: unmanagedSelf
        )

        if let eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            if let runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
                CGEvent.tapEnable(tap: eventTap, enable: true)
                store.addLog("CGEventTap 全局热键监听启动成功")
            } else {
                store.addLog("CGEventTap 全局热键监听启动失败：无法创建 RunLoop Source")
            }
        } else {
            store.addLog("CGEventTap 全局热键监听启动失败：\(PermissionManager.keyboardPermissionSummary(language: store.language))")
            Notifier.shared.error("全局快捷键监听启动失败，请检查辅助功能权限。")
        }

        startNSEventMonitors()
    }

    private func startNSEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleNSEvent(event, source: "NSEvent 全局监听")
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleNSEvent(event, source: "NSEvent 本地监听")
            }
            return event
        }

        store.addLog("NSEvent 兜底监听已启动")
    }

    private func handleNSEvent(_ event: NSEvent, source: String) {
        let keyCode = UInt16(event.keyCode)
        let hotkeyEvent = nsEventState.handle(keyCode: keyCode, flags: event.modifierFlags.cgEventFlags)

        switch hotkeyEvent {
        case .none:
            return
        case .armed(let firstKeyName, let secondKeyName):
            store.addLog("\(source) 收到前导键：\(firstKeyName)，等待 \(secondKeyName)")
        case .trigger(let binding):
            store.addLog("\(source) 收到完整快捷键：\(binding.hotkey.displayName)")
            trigger(binding.action, targetApplication: NSWorkspace.shared.frontmostApplication)
        case .secondaryMismatch(let keyName):
            store.addLog("\(source) 第二键不匹配：收到 \(keyName)")
        case .expired:
            store.addLog("\(source) 快捷键等待超时")
        }
    }

    private func currentBindings() -> [HotkeyBinding] {
        var bindings = [HotkeyBinding(action: .rewrite, hotkey: store.hotkey)]
        if store.previewEnabled {
            bindings.append(HotkeyBinding(action: .dictation, hotkey: store.dictationHotkey))
        }
        return bindings
    }

    private func trigger(_ action: HotkeyAction, targetApplication: NSRunningApplication?) {
        switch action {
        case .rewrite:
            onRewriteTrigger(targetApplication)
        case .dictation:
            onDictationTrigger(targetApplication)
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        eventTap = nil
        runLoopSource = nil
        store.addLog("全局热键监听已停止")
    }
}

private extension NSEvent.ModifierFlags {
    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        return flags
    }
}
