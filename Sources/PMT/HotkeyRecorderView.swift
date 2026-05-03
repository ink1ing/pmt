import AppKit
import SwiftUI

struct HotkeyRecorder: NSViewRepresentable {
    @Binding var hotkey: HotkeyConfig

    func makeNSView(context: Context) -> RecorderField {
        let view = RecorderField()
        view.onChange = { hotkey in
            self.hotkey = hotkey
        }
        view.stringValue = hotkey.displayName
        return view
    }

    func updateNSView(_ nsView: RecorderField, context: Context) {
        nsView.stringValue = hotkey.displayName
    }
}

final class RecorderField: NSTextField {
    var onChange: ((HotkeyConfig) -> Void)?
    private var pendingFirstKey: (keyCode: UInt16, carbonModifiers: UInt32)?

    init() {
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isBordered = true
        drawsBackground = true
        alignment = .center
        focusRingType = .default
        placeholderString = "点击后按两个键"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        pendingFirstKey = nil
        stringValue = "按下第一个键"
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let carbonModifiers = HotkeyConfig.carbonModifiers(from: flags.cgEventFlags)
        let keyCode = UInt16(event.keyCode)

        if let first = pendingFirstKey {
            let display = HotkeyConfig.chordDisplayName(
                keyCode: first.keyCode,
                carbonModifiers: first.carbonModifiers,
                secondaryKeyCode: keyCode
            )
            let config = HotkeyConfig(
                keyCode: first.keyCode,
                carbonModifiers: first.carbonModifiers,
                secondaryKeyCode: keyCode,
                displayName: display
            )
            stringValue = display
            pendingFirstKey = nil
            onChange?(config)
            window?.makeFirstResponder(nil)
            return
        }

        pendingFirstKey = (keyCode, carbonModifiers)
        let display = HotkeyConfig.chordDisplayName(
            keyCode: keyCode,
            carbonModifiers: carbonModifiers,
            secondaryKeyCode: nil
        )
        stringValue = display
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
