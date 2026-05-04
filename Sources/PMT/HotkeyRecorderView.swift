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

final class RecorderField: NSControl {
    var onChange: ((HotkeyConfig) -> Void)?
    private var pendingFirstKey: (keyCode: UInt16, carbonModifiers: UInt32)?
    private var committedDisplayValue = ""
    private let label = NSTextField(labelWithString: "")
    private var isRecording = false {
        didSet { updateAppearance() }
    }

    override var stringValue: String {
        get { label.stringValue }
        set {
            label.stringValue = newValue
            if committedDisplayValue.isEmpty, !newValue.isEmpty {
                committedDisplayValue = newValue
            }
        }
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.masksToBounds = false

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        label.textColor = .labelColor
        label.allowsDefaultTighteningForTruncation = true
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        pendingFirstKey = nil
        committedDisplayValue = stringValue
        stringValue = "按下第一个键"
        isRecording = true
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
            committedDisplayValue = display
            pendingFirstKey = nil
            onChange?(config)
            isRecording = false
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
        let config = HotkeyConfig(
            keyCode: keyCode,
            carbonModifiers: carbonModifiers,
            secondaryKeyCode: nil,
            displayName: display
        )
        committedDisplayValue = display
        onChange?(config)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        if pendingFirstKey != nil {
            pendingFirstKey = nil
            stringValue = committedDisplayValue
        }
        return super.resignFirstResponder()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func updateAppearance() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(isRecording ? 1.0 : 0.78).cgColor
        layer?.borderColor = (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = isRecording ? 0.14 : 0.05
        layer?.shadowRadius = isRecording ? 5 : 2
        layer?.shadowOffset = CGSize(width: 0, height: 1)
        label.textColor = isRecording ? .controlAccentColor : .labelColor
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
