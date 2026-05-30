import AppKit
import QuartzCore

@MainActor
final class RewriteActivityIndicator {
    private var panel: NSPanel?
    private var followTimer: Timer?
    private var currentScreenFrame: NSRect?
    private let size = NSSize(width: 118, height: 26)

    func show(symbol: String = "🤔") {
        teardownImmediately()

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let contentView = ActivityProgressView(frame: NSRect(origin: .zero, size: size), symbol: symbol)
        panel.contentView = contentView
        self.panel = panel

        repositionToMouseScreen()
        panel.orderFrontRegardless()
        contentView.startAnimating()
        startFollowing()
    }

    /// 完成时快速补满并淡出；失败时标红不补满直接淡出。
    func hide(completed: Bool = true) {
        stopFollowing()
        guard let panel else { return }
        self.panel = nil
        guard let view = panel.contentView as? ActivityProgressView else {
            panel.orderOut(nil)
            return
        }
        view.dismiss(completed: completed) {
            panel.orderOut(nil)
        }
    }

    private func teardownImmediately() {
        stopFollowing()
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - 屏幕底部居中 + 跟随鼠标所在屏幕

    private func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    private func repositionToMouseScreen() {
        guard let panel, let screen = screenUnderMouse() else { return }
        currentScreenFrame = screen.frame
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + 60
        ))
    }

    private func startFollowing() {
        followTimer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let screen = self.screenUnderMouse() else { return }
                if screen.frame != self.currentScreenFrame {
                    self.repositionToMouseScreen()
                }
            }
        }
        followTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopFollowing() {
        followTimer?.invalidate()
        followTimer = nil
    }
}

/// 统一的活动进度视图：左侧静态阶段图标 + 右侧非匀速进度条，整体为小型药丸状。
/// 进度由 Core Animation 在渲染端插值驱动，先快后慢逼近 92%，完成时再补满。
private final class ActivityProgressView: NSView {
    private let track = CALayer()
    private let fill = CALayer()
    private let glyph = CATextLayer()
    private let symbol: String

    init(frame frameRect: NSRect, symbol: String) {
        self.symbol = symbol
        super.init(frame: frameRect)
        let scale = NSScreen.main?.backingScaleFactor ?? 2

        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.94).cgColor
        layer?.cornerRadius = frameRect.height / 2
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor

        glyph.string = symbol
        glyph.font = NSFont.systemFont(ofSize: 13)
        glyph.fontSize = 13
        glyph.alignmentMode = .center
        glyph.contentsScale = scale
        layer?.addSublayer(glyph)

        track.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.22).cgColor
        track.cornerRadius = 2
        layer?.addSublayer(track)

        fill.backgroundColor = NSColor.controlAccentColor.cgColor
        fill.cornerRadius = 2
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        track.addSublayer(fill)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let glyphSize: CGFloat = 16
        glyph.frame = CGRect(x: 8, y: (bounds.height - glyphSize) / 2 - 1, width: glyphSize, height: glyphSize)
        let trackX = glyph.frame.maxX + 6
        let trackHeight: CGFloat = 4
        let trackWidth = max(bounds.width - trackX - 10, 0)
        track.frame = CGRect(x: trackX, y: (bounds.height - trackHeight) / 2, width: trackWidth, height: trackHeight)
        fill.position = CGPoint(x: 0, y: trackHeight / 2)
        fill.bounds = CGRect(x: 0, y: 0, width: 0, height: trackHeight)
        CATransaction.commit()
    }

    private var trackWidth: CGFloat { track.bounds.width }

    func startAnimating() {
        layoutSubtreeIfNeeded()
        let target = trackWidth * 0.92
        let animation = CABasicAnimation(keyPath: "bounds.size.width")
        animation.fromValue = trackWidth * 0.04
        animation.toValue = target
        animation.duration = 16
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0, 0.8, 0.2, 1)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        fill.bounds.size.width = target
        fill.add(animation, forKey: "progress")
    }

    func dismiss(completed: Bool, completion: @escaping () -> Void) {
        layoutSubtreeIfNeeded()

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            MainActor.assumeIsolated { completion() }
        }

        if completed {
            let current = fill.presentation()?.bounds.width ?? (trackWidth * 0.92)
            fill.removeAnimation(forKey: "progress")
            let grow = CABasicAnimation(keyPath: "bounds.size.width")
            grow.fromValue = current
            grow.toValue = trackWidth
            grow.duration = 0.22
            grow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            grow.fillMode = .forwards
            grow.isRemovedOnCompletion = false
            fill.bounds.size.width = trackWidth
            fill.add(grow, forKey: "finish")
        } else {
            fill.backgroundColor = NSColor.systemRed.cgColor
        }

        if let layer {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1.0
            fade.toValue = 0.0
            fade.beginTime = CACurrentMediaTime() + (completed ? 0.16 : 0.0)
            fade.duration = completed ? 0.16 : 0.2
            fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false
            layer.opacity = 0
            layer.add(fade, forKey: "fade")
        }

        CATransaction.commit()
    }
}
