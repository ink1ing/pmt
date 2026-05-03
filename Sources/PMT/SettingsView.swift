import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    let onSave: () -> Void

    private var language: AppLanguage { store.language }

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
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text(.api))
                .font(.headline)
            TextField(language.text(.endpointURL), text: $store.endpointURL)
                .textFieldStyle(.roundedBorder)
            SecureField("API Key", text: $store.apiKey)
                .textFieldStyle(.roundedBorder)
            HStack {
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
                .frame(maxWidth: .infinity)

                Button(language.text(.loadModels)) {
                    store.saveAPISection()
                    Task { await store.loadModels() }
                }
                Button(language.text(.testModel)) {
                    store.saveAPISection()
                    Task { await store.testConnection() }
                }
            }
            TextField(language.text(.manualModelID), text: $store.selectedModel)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(language.text(.saveAPI)) {
                    store.saveAPISection()
                }
            }
        }
        .disabled(store.isBusy)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.text(.prompt))
                    .font(.headline)
                Spacer()
                Picker("", selection: $store.rewriteMode) {
                    ForEach(RewriteMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
            if store.rewriteMode == .custom {
                TextEditor(text: $store.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )
            }
            HStack {
                Spacer()
                Button(language.text(.savePrompt)) {
                    store.savePromptSection()
                }
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
                Button(language.text(.restoreControlX)) {
                    store.hotkey = .defaultControlX
                }
                Button(language.text(.saveHotkey)) {
                    store.saveHotkeySection()
                    onSave()
                }
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
            HStack {
                Text(language.text(.language))
                    .font(.headline)
                Spacer()
                Picker("", selection: $store.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            HStack {
                Spacer()
                Button(language.text(.saveLanguage)) {
                    store.saveLanguageSection()
                }
            }
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
