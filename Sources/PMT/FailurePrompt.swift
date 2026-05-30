import AppKit
import SwiftUI

/// 操作失败时弹出，提供「重试」按钮。重试逻辑由调用方传入，携带已捕获的输入，
/// 只重跑失败环节（通常是模型/网络请求），网络恢复后一点即成。
@MainActor
final class FailurePrompt {
    static let shared = FailurePrompt()
    private var window: NSWindow?

    func show(message: String, language: AppLanguage, onRetry: @escaping () -> Void) {
        window?.close()
        let view = FailurePromptView(
            message: message,
            language: language,
            onRetry: { [weak self] in self?.close(); onRetry() },
            onCancel: { [weak self] in self?.close() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.styleMask = [.titled, .closable]
        window.title = language.text(.failureTitle)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
    }

    private func close() {
        window?.close()
        window = nil
    }
}

private struct FailurePromptView: View {
    let message: String
    let language: AppLanguage
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(language.text(.cancel)) { onCancel() }
                Button(language.text(.retry)) { onRetry() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}
