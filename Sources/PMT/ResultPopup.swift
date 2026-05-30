import AppKit
import SwiftUI

/// 当焦点处没有可编辑输入框时，弹出结果窗口供用户查看与复制。
@MainActor
final class ResultPopup {
    static let shared = ResultPopup()
    private var window: NSWindow?

    func show(text: String, language: AppLanguage) {
        window?.close()
        let view = ResultPopupView(text: text, language: language) { [weak self] in
            self?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.styleMask = [.titled, .closable]
        window.title = language.text(.resultTitle)
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

private struct ResultPopupView: View {
    let text: String
    let language: AppLanguage
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                Text(text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 180)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))

            HStack {
                Spacer()
                Button(language.text(.copy)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
                Button(language.text(.close)) { onClose() }
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}
