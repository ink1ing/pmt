import AppKit
import Foundation

@MainActor
final class SelectionRewriter {
    private let store: ConfigStore
    private var isRunning = false

    init(store: ConfigStore) {
        self.store = store
    }

    func rewriteSelection(targetApplication: NSRunningApplication?) {
        guard !isRunning else {
            store.addLog("忽略触发：上一次改写仍在执行")
            return
        }
        isRunning = true
        store.addLog("收到改写触发，目标：\(FrontmostAppTracker.displayName(for: targetApplication))")

        Task {
            defer {
                Task { @MainActor in
                    self.isRunning = false
                }
            }

            do {
                try ensureAccessibility()
                store.addLog("辅助功能权限检查通过")
                store.save()

                let snapshot = ClipboardSnapshot()
                try await activateTargetApplication(targetApplication)
                let selectedText = try await copySelectedText()
                store.addLog("读取选中文本成功：\(selectedText.count) 个字符")
                let client = try store.apiClient()
                store.addLog("开始请求模型：\(store.selectedModel.isEmpty ? "未选择模型" : store.selectedModel)")
                let rewritten = try await client.rewrite(
                    text: selectedText,
                    model: store.selectedModel,
                    systemPrompt: store.systemPrompt,
                    mode: store.rewriteMode
                )
                store.addLog("模型返回成功：\(rewritten.count) 个字符")
                try await activateTargetApplication(targetApplication)
                try paste(rewritten)
                store.addLog("已粘贴替换文本")

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    snapshot.restore()
                    store.addLog("已恢复原剪贴板")
                }
            } catch {
                store.addLog("改写失败：\(error.localizedDescription)")
                Notifier.shared.error(error.localizedDescription)
            }
        }
    }

    private func ensureAccessibility() throws {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            throw PMTError.accessibilityMissing
        }
    }

    private func copySelectedText() async throws -> String {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        store.addLog("发送 Cmd+C 读取选中文本")
        Keyboard.pressCommandKey(8)
        try await Task.sleep(nanoseconds: 220_000_000)

        guard let selectedText = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !selectedText.isEmpty else {
            throw PMTError.noSelectedText
        }
        return selectedText
    }

    private func paste(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw PMTError.clipboard("无法写入剪贴板。")
        }
        store.addLog("发送 Cmd+V 替换选中文本")
        Keyboard.pressCommandKey(9)
    }

    private func activateTargetApplication(_ application: NSRunningApplication?) async throws {
        guard let application else {
            store.addLog("未找到外部目标 App，将在当前前台 App 中尝试")
            return
        }

        store.addLog("激活目标 App：\(FrontmostAppTracker.displayName(for: application))")
        application.activate(options: [])
        try await Task.sleep(nanoseconds: 240_000_000)
    }
}
