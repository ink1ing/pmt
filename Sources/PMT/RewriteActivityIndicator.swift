import AppKit
import QuartzCore

@MainActor
final class RewriteActivityIndicator {
    private var panel: NSPanel?

    func show(symbol: String = "🤔") {
        hide()

        let size = NSSize(width: 68, height: 44)
        let mouseLocation = NSEvent.mouseLocation
        let origin = NSPoint(
            x: mouseLocation.x + 12,
            y: mouseLocation.y - size.height - 12
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let contentView = EmojiSpinnerView(frame: NSRect(origin: .zero, size: size), symbol: symbol)
        panel.contentView = contentView
        panel.orderFrontRegardless()
        contentView.startAnimating()
        self.panel = panel
    }

    func hide() {
        guard let panel else { return }
        (panel.contentView as? EmojiSpinnerView)?.stopAnimating()
        panel.orderOut(nil)
        self.panel = nil
    }
}

private final class EmojiSpinnerView: NSView {
    private var timer: Timer?
    private var rotation: CGFloat = 0
    private let symbol: String

    init(frame frameRect: NSRect, symbol: String) {
        self.symbol = symbol
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let attributedEmoji = NSAttributedString(
            string: symbol,
            attributes: [
                .font: NSFont.systemFont(ofSize: 28),
                .foregroundColor: NSColor.labelColor
            ]
        )
        let emojiSize = attributedEmoji.size()
        let emojiRect = NSRect(
            x: -emojiSize.width / 2,
            y: -emojiSize.height / 2,
            width: emojiSize.width,
            height: emojiSize.height
        )

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: rotation)
        attributedEmoji.draw(in: emojiRect)
        context.restoreGState()
    }

    func startAnimating() {
        timer?.invalidate()
        rotation = 0
        needsDisplay = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.rotation += (CGFloat.pi * 2) / 60.0
                if self.rotation >= CGFloat.pi * 2 {
                    self.rotation -= CGFloat.pi * 2
                }
                self.needsDisplay = true
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }
}
