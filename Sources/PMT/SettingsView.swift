import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            apiSection
            Divider()
            promptSection
            Divider()
            hotkeySection
            Divider()
            statusBarSection
            Divider()
            permissionsSection
            Divider()
            logSection
            HStack {
                Text(store.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button("保存") {
                    store.save()
                    onSave()
                    store.statusMessage = "已保存"
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("API")
                .font(.headline)
            TextField("端点 URL", text: $store.endpointURL)
                .textFieldStyle(.roundedBorder)
            SecureField("API Key", text: $store.apiKey)
                .textFieldStyle(.roundedBorder)
            HStack {
                Picker("模型", selection: $store.selectedModel) {
                    if store.selectedModel.isEmpty {
                        Text("未选择").tag("")
                    }
                    ForEach(store.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                    if !store.selectedModel.isEmpty, !store.availableModels.contains(store.selectedModel) {
                        Text(store.selectedModel).tag(store.selectedModel)
                    }
                }
                .frame(maxWidth: .infinity)

                Button("读取模型") {
                    store.save()
                    Task { await store.loadModels() }
                }
                Button("测试 API") {
                    store.save()
                    Task { await store.testConnection() }
                }
            }
            TextField("手动模型 ID", text: $store.selectedModel)
                .textFieldStyle(.roundedBorder)
        }
        .disabled(store.isBusy)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Prompt")
                    .font(.headline)
                Spacer()
                Picker("", selection: $store.rewriteMode) {
                    ForEach(RewriteMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            TextEditor(text: $store.systemPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                )
        }
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快捷键")
                .font(.headline)
            HStack {
                HotkeyRecorder(hotkey: $store.hotkey)
                    .frame(width: 180, height: 30)
                Button("恢复 Ctrl + X") {
                    store.hotkey = .defaultControlX
                }
                Spacer()
            }
        }
    }

    private var statusBarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("状态栏")
                .font(.headline)
            Toggle("显示顶部状态栏图标", isOn: $store.statusBarIconEnabled)
                .toggleStyle(.checkbox)
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("权限")
                .font(.headline)
            HStack {
                Button("检查辅助功能") {
                    let message = PermissionManager.accessibilityStatus()
                    store.statusMessage = message
                    store.addLog(message)
                }
                Button("请求辅助功能权限") {
                    let message = PermissionManager.requestAccessibilityAccess()
                    store.statusMessage = message
                    store.addLog(message)
                }
                Button("打开辅助功能设置") {
                    store.addLog("打开辅助功能设置")
                    PermissionManager.openAccessibilitySettings()
                }
                Button("打开输入监控设置") {
                    store.addLog("打开输入监控设置")
                    PermissionManager.openInputMonitoringSettings()
                }
            }
            HStack {
                Button("检查输入监控") {
                    let message = PermissionManager.inputMonitoringStatus()
                    store.statusMessage = message
                    store.addLog(message)
                }
                Button("请求输入监控权限") {
                    let message = PermissionManager.requestInputMonitoringAccess()
                    store.statusMessage = message
                    store.addLog(message)
                }
                Button("检查键盘权限") {
                    let message = PermissionManager.keyboardPermissionSummary()
                    store.statusMessage = message
                    store.addLog(message)
                }
                Button("重启热键监听") {
                    store.addLog("手动重启热键监听")
                    store.save()
                    onSave()
                }
            }
            HStack {
                Button("检查通知权限") {
                    Task {
                        let message = await PermissionManager.notificationStatus()
                        store.statusMessage = message
                        store.addLog(message)
                    }
                }
                Button("打开通知设置") {
                    store.addLog("打开通知设置")
                    PermissionManager.openNotificationSettings()
                }
                Button("打开隐私与安全") {
                    store.addLog("打开隐私与安全")
                    PermissionManager.openPrivacySettings()
                }
            }
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("日志")
                    .font(.headline)
                Spacer()
                Button("清空") {
                    store.clearLogs()
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.logs) { entry in
                            Text(store.formattedLogLine(entry))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .frame(height: 120)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                )
                .onChange(of: store.logs.count) {
                    if let last = store.logs.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
