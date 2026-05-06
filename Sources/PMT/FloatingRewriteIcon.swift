import AppKit

@MainActor
final class FloatingRewriteIcon {
    private var panel: NSPanel?
    private let defaults = UserDefaults(suiteName: "dev.pmt.PMT.shared") ?? .standard
    private let positionKey = "PMT.floatingIcon.origin"
    private let onRewrite: () -> Void
    private let onOpenSettings: () -> Void

    init(onRewrite: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onRewrite = onRewrite
        self.onOpenSettings = onOpenSettings
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show() {
        if let panel {
            panel.orderFrontRegardless()
            return
        }

        let size = NSSize(width: 54, height: 54)
        let panel = NSPanel(
            contentRect: NSRect(origin: savedOrigin(for: size), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false

        let contentView = FloatingRewriteIconView(
            frame: NSRect(origin: .zero, size: size),
            onRewrite: { [weak self] in self?.onRewrite() },
            onOpenSettings: { [weak self] in self?.onOpenSettings() },
            onMove: { [weak self] origin in self?.saveOrigin(origin) }
        )
        panel.contentView = contentView
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        guard let panel else { return }
        panel.orderOut(nil)
        self.panel = nil
    }

    private func savedOrigin(for size: NSSize) -> NSPoint {
        if let string = defaults.string(forKey: positionKey) {
            let point = NSPointFromString(string)
            if point != .zero {
                return constrainedOrigin(point, size: size)
            }
        }

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return NSPoint(
            x: visibleFrame.maxX - size.width - 28,
            y: visibleFrame.midY - size.height / 2
        )
    }

    private func saveOrigin(_ origin: NSPoint) {
        guard let panel else { return }
        let constrained = constrainedOrigin(origin, size: panel.frame.size)
        if constrained != panel.frame.origin {
            panel.setFrameOrigin(constrained)
        }
        defaults.set(NSStringFromPoint(constrained), forKey: positionKey)
    }

    private func constrainedOrigin(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let screens = NSScreen.screens
        let screen = screens.first { $0.visibleFrame.insetBy(dx: -80, dy: -80).contains(origin) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return NSPoint(
            x: min(max(origin.x, frame.minX + 6), frame.maxX - size.width - 6),
            y: min(max(origin.y, frame.minY + 6), frame.maxY - size.height - 6)
        )
    }
}

private final class FloatingRewriteIconView: NSView {
    private let onRewrite: () -> Void
    private let onOpenSettings: () -> Void
    private let onMove: (NSPoint) -> Void
    private var longPressTimer: Timer?
    private var isDragging = false
    private var mouseDownScreenPoint = NSPoint.zero
    private var panelStartOrigin = NSPoint.zero

    init(
        frame frameRect: NSRect,
        onRewrite: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onMove: @escaping (NSPoint) -> Void
    ) {
        self.onRewrite = onRewrite
        self.onOpenSettings = onOpenSettings
        self.onMove = onMove
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let backgroundRect = bounds.insetBy(dx: 4, dy: 4)
        let background = NSBezierPath(roundedRect: backgroundRect, xRadius: 18, yRadius: 18)
        NSColor.windowBackgroundColor.withAlphaComponent(0.88).setFill()
        background.fill()
        NSColor.separatorColor.withAlphaComponent(0.55).setStroke()
        background.lineWidth = 1
        background.stroke()

        let emoji = NSAttributedString(
            string: "🤔",
            attributes: [.font: NSFont.systemFont(ofSize: 28)]
        )
        let emojiSize = emoji.size()
        emoji.draw(
            at: NSPoint(
                x: bounds.midX - emojiSize.width / 2,
                y: bounds.midY - emojiSize.height / 2 + 1
            )
        )
    }

    override func rightMouseDown(with event: NSEvent) {
        cancelLongPress()
        onOpenSettings()
    }

    override func mouseDown(with event: NSEvent) {
        guard event.buttonNumber == 0 else { return }
        mouseDownScreenPoint = NSEvent.mouseLocation
        panelStartOrigin = window?.frame.origin ?? .zero
        isDragging = false
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.32, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isDragging = true
                NSCursor.closedHand.push()
            }
        }
        RunLoop.main.add(longPressTimer!, forMode: .common)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let window else { return }
        let current = NSEvent.mouseLocation
        let nextOrigin = NSPoint(
            x: panelStartOrigin.x + current.x - mouseDownScreenPoint.x,
            y: panelStartOrigin.y + current.y - mouseDownScreenPoint.y
        )
        window.setFrameOrigin(nextOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        let dragged = isDragging
        cancelLongPress()

        if dragged {
            if let origin = window?.frame.origin {
                onMove(origin)
            }
        } else {
            onRewrite()
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            cancelLongPress()
        }
    }

    private func cancelLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        if isDragging {
            NSCursor.pop()
        }
        isDragging = false
    }
}
