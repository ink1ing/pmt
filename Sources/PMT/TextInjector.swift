import AppKit

/// 统一的剪贴板文本读写，复制用 changeCount 轮询替代固定 sleep，
/// 粘贴后按延时恢复调用方提供的原始剪贴板快照。
@MainActor
enum TextInjector {
    /// 通过 Cmd+C 读取当前选中文本。轮询剪贴板 changeCount 变化，
    /// 在超时内拿到非空内容则返回，否则抛出 noSelectedText。
    static func copySelection(timeout: TimeInterval = 1.0) async throws -> String {
        let pasteboard = NSPasteboard.general
        let beforeCount = pasteboard.changeCount
        Keyboard.pressCommandKey(8) // Cmd+C

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000) // 30ms
            guard pasteboard.changeCount != beforeCount else { continue }
            if let text = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
        }
        throw PMTError.noSelectedText
    }

    /// 写入文本并通过 Cmd+V 粘贴，随后在 restoreDelay 后恢复传入的原始快照。
    static func paste(
        _ text: String,
        restoring snapshot: ClipboardSnapshot,
        restoreDelay: TimeInterval = 0.9
    ) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw PMTError.clipboard("无法写入剪贴板。")
        }
        Keyboard.pressCommandKey(9) // Cmd+V
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(restoreDelay * 1_000_000_000))
            snapshot.restore()
        }
    }

    /// 直接把文本作为 unicode 键事件敲入当前光标处，用于流式增量输出。
    static func typeText(_ text: String) {
        guard !text.isEmpty, let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let utf16 = Array(text.utf16)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
        down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
