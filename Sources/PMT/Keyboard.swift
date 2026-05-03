import AppKit

enum Keyboard {
    static func pressCommandKey(_ keyCode: CGKeyCode) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
