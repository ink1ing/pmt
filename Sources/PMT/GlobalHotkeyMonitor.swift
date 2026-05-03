import AppKit

private final class HotkeyRuntimeState: @unchecked Sendable {
    private let lock = NSLock()
    private var hotkey: HotkeyConfig = .defaultControlX
    private var chordArmedUntil: Date?
    private let chordTimeout: TimeInterval = 1.2

    func updateHotkey(_ hotkey: HotkeyConfig) {
        lock.lock()
        self.hotkey = hotkey
        chordArmedUntil = nil
        lock.unlock()
    }

    func handle(keyCode: UInt16, flags: CGEventFlags) -> HotkeyEvent {
        lock.lock()
        defer { lock.unlock() }

        if let chordArmedUntil {
            guard Date() <= chordArmedUntil else {
                self.chordArmedUntil = nil
                return .expired
            }

            if hotkey.matchesSecondary(keyCode: keyCode) {
                self.chordArmedUntil = nil
                return .trigger(hotkey.displayName)
            }

            self.chordArmedUntil = nil
            return .secondaryMismatch(HotkeyConfig.keyName(for: keyCode))
        }

        if hotkey.matches(keyCode: keyCode, flags: flags) {
            if let secondaryKeyCode = hotkey.secondaryKeyCode {
                chordArmedUntil = Date().addingTimeInterval(chordTimeout)
                return .armed(
                    firstKeyName: HotkeyConfig.keyName(for: keyCode),
                    secondKeyName: HotkeyConfig.keyName(for: secondaryKeyCode)
                )
            }
            return .trigger(hotkey.displayName)
        }

        return .none
    }
}

private enum HotkeyEvent {
    case none
    case armed(firstKeyName: String, secondKeyName: String)
    case trigger(String)
    case secondaryMismatch(String)
    case expired
}

@MainActor
final class GlobalHotkeyMonitor {
    private let store: ConfigStore
    private let onTrigger: (NSRunningApplication?) -> Void
    private let eventTapState = HotkeyRuntimeState()
    private let nsEventState = HotkeyRuntimeState()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(store: ConfigStore, onTrigger: @escaping (NSRunningApplication?) -> Void) {
        self.store = store
        self.onTrigger = onTrigger
    }

    func start() {
        stop()
        eventTapState.updateHotkey(store.hotkey)
        nsEventState.updateHotkey(store.hotkey)
        store.addLog("启动全局热键监听：\(store.hotkey.displayName)")
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
                case .trigger(let displayName):
                    Task { @MainActor in
                        monitor.store.addLog("CGEventTap 收到完整快捷键：\(displayName)")
                        monitor.onTrigger(NSWorkspace.shared.frontmostApplication)
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
        case .trigger(let displayName):
            store.addLog("\(source) 收到完整快捷键：\(displayName)")
            onTrigger(NSWorkspace.shared.frontmostApplication)
        case .secondaryMismatch(let keyName):
            store.addLog("\(source) 第二键不匹配：收到 \(keyName)")
        case .expired:
            store.addLog("\(source) 快捷键等待超时")
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
