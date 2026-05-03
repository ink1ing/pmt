import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    let onSave: () -> Void

    private var language: AppLanguage { store.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            usageSection
            Divider()
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
            logToggleSection
            if store.showLogs {
                logSection
            }
            Divider()
            languageSection
            HStack {
                Text(store.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(language.text(.saveAll)) {
                    store.saveAllSections()
                    onSave()
                }
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用说明")
                .font(.headline)
            Text("1. 授予必要的权限")
            Text("2. 配置可用的模型")
            Text("3. 配置全局快捷键和风格偏好")
            Text("4. 在任意应用中选中文字，极速改写提示词")
        }
    }

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.text(.api))
                .font(.headline)
            TextField(language.text(.endpointURL), text: $store.endpointURL)
                .textFieldStyle(.roundedBorder)
            SecureField(language.text(.apiKey), text: $store.apiKey)
                .textFieldStyle(.roundedBorder)
            Picker(language.text(.model), selection: $store.selectedModel) {
                if store.selectedModel.isEmpty {
                    Text(language.text(.unselected)).tag("")
                }
                ForEach(store.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
                if !store.selectedModel.isEmpty, !store.availableModels.contains(store.selectedModel) {
                    Text(store.selectedModel).tag(store.selectedModel)
                }
            }
            HStack {
                Button(language.text(.loadModels)) {
                    Task { await store.loadModels() }
                }
                Button(language.text(.testModel)) {
                    Task { await store.testConnection() }
                }
                Spacer()
            }
        }
        .disabled(store.isBusy)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text(.prompt))
                .font(.headline)
            Picker("", selection: $store.rewriteMode) {
                ForEach(RewriteMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240, alignment: .leading)
            if store.rewriteMode == .custom {
                TextEditor(text: $store.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )
            }
        }
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text(.hotkey))
                .font(.headline)
            HStack {
                HotkeyRecorder(hotkey: $store.hotkey)
                    .frame(width: 180, height: 30)
                Spacer()
            }
        }
    }

    private var statusBarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text(.statusBar))
                .font(.headline)
            Toggle(language.text(.showStatusBarIcon), isOn: $store.statusBarIconEnabled)
                .toggleStyle(.checkbox)
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text(.permissions))
                .font(.headline)
            HStack {
                Button(language.text(.checkAccessibility)) {
                    let message = PermissionManager.accessibilityStatus(language: language)
                    store.statusMessage = message
                    store.addLog(message)
                }
                Button(language.text(.requestAccessibility)) {
                    let message = PermissionManager.requestAccessibilityAccess(language: language)
                    store.statusMessage = message
                    store.addLog(message)
                }
            }
            HStack {
                Button(language.text(.checkInputMonitoring)) {
                    let message = PermissionManager.inputMonitoringStatus(language: language)
                    store.statusMessage = message
                    store.addLog(message)
                }
                Button(language.text(.requestInputMonitoring)) {
                    let message = PermissionManager.requestInputMonitoringAccess(language: language)
                    store.statusMessage = message
                    store.addLog(message)
                }
            }
            HStack {
                Button(language.text(.checkKeyboardPermissions)) {
                    let message = PermissionManager.keyboardPermissionSummary(language: language)
                    store.statusMessage = message
                    store.addLog(message)
                }
                Button(language.text(.restartHotkeyMonitor)) {
                    store.addLog(language == .zhHans ? "手动重启热键监听" : "Hotkey monitor restarted manually")
                    store.saveConfig()
                    onSave()
                }
            }
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text(.language))
                .font(.headline)
            Picker("", selection: $store.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180, alignment: .leading)
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.text(.logs))
                    .font(.headline)
                Spacer()
                Button(language.text(.clear)) {
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

    private var logToggleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(language.text(.showLogs), isOn: $store.showLogs)
                .toggleStyle(.checkbox)
        }
    }
}
