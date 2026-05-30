import AppKit
import Foundation

@MainActor
final class SelectionRewriter {
    private let store: ConfigStore
    private let activityIndicator = RewriteActivityIndicator()
    private var isRunning = false

    init(store: ConfigStore) {
        self.store = store
    }

    func rewriteSelection(targetApplication: NSRunningApplication?) {
        guard !isRunning else {
            store.addLog("忽略触发：上一次改写仍在执行")
            return
        }
        store.addLog("收到改写触发，目标：\(FrontmostAppTracker.displayName(for: targetApplication))")
        run(targetApplication: targetApplication, capturedText: nil, snapshot: ClipboardSnapshot())
    }

    /// capturedText 非空时跳过 Cmd+C 直接重试模型与投递；snapshot 贯穿重试以正确恢复剪贴板。
    private func run(targetApplication: NSRunningApplication?, capturedText: String?, snapshot: ClipboardSnapshot) {
        guard !isRunning else {
            store.addLog("忽略触发：上一次改写仍在执行")
            return
        }
        isRunning = true
        activityIndicator.show()

        Task {
            var succeeded = false
            var selectedText = capturedText
            defer {
                let done = succeeded
                Task { @MainActor in
                    self.activityIndicator.hide(completed: done)
                    self.isRunning = false
                }
            }

            do {
                try ensureAccessibility()
                store.addLog("辅助功能权限检查通过")
                store.saveConfig()

                try await activateTargetApplication(targetApplication)
                if selectedText == nil {
                    store.addLog("发送 Cmd+C 读取选中文本")
                    let captured = try await TextInjector.copySelection()
                    store.addLog("读取选中文本成功：\(captured.count) 个字符")
                    store.recordAdviceInput(captured, source: "rewrite")
                    selectedText = captured
                }
                guard let text = selectedText else { throw PMTError.noSelectedText }

                store.addLog("开始请求模型：\(store.selectedModel.isEmpty ? "未选择模型" : store.selectedModel)")
                try await activateTargetApplication(targetApplication)

                let editable = FocusedField.hasEditableFocus()
                if editable && store.streamingEnabled {
                    snapshot.restore()
                    var count = 0
                    for try await delta in try store.rewriteStream(text: text) {
                        TextInjector.typeText(delta)
                        count += delta.count
                    }
                    store.addLog("流式输出完成：\(count) 个字符")
                } else {
                    let rewritten = try await store.rewrite(text: text)
                    store.addLog("模型返回成功：\(rewritten.count) 个字符")
                    if editable {
                        store.addLog("发送 Cmd+V 替换选中文本")
                        try TextInjector.paste(rewritten, restoring: snapshot)
                        store.addLog("已粘贴替换文本")
                    } else {
                        snapshot.restore()
                        ResultPopup.shared.show(text: rewritten, language: store.language)
                        store.addLog("无活跃输入框，已弹出结果窗口")
                    }
                }
                succeeded = true
            } catch {
                store.addLog("改写失败：\(error.localizedDescription)")
                let captured = selectedText
                FailurePrompt.shared.show(message: error.localizedDescription, language: store.language) { [weak self] in
                    self?.run(targetApplication: targetApplication, capturedText: captured, snapshot: snapshot)
                }
            }
        }
    }

    private func ensureAccessibility() throws {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            throw PMTError.accessibilityMissing
        }
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
