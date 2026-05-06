import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    let dictationWorkflow: DictationWorkflow?
    let onSave: () -> Void

    private var language: AppLanguage { store.language }
    private let controlWidth: CGFloat = 240
    private let hotkeyControlWidth: CGFloat = 60
    private let modelColumnWidth: CGFloat = 240
    private var isAppReady: Bool {
        hasRequiredPermissions && hasModelCredential && hasBoundHotkey
    }
    private var hasRequiredPermissions: Bool {
        PermissionManager.hasAccessibilityAccess && PermissionManager.hasInputMonitoringAccess
    }
    private var hasModelCredential: Bool {
        !store.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !store.githubOAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var hasBoundHotkey: Bool {
        !store.hotkey.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let normalized = version?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized?.isEmpty == false ? "v\(normalized!)" : "v0.0.84"
    }
    private var readinessText: String {
        if language == .zhHans {
            return "\(appVersion) \(isAppReady ? "已就绪" : "未就绪")"
        }
        return "\(appVersion) \(isAppReady ? "Ready" : "Not Ready")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            usageSection
            Divider()
            permissionsSection
            Divider()
            apiSection
            Divider()
            promptAndHotkeySection
            Divider()
            previewSection
            Divider()
            bottomSection
        }
        .padding(18)
        .frame(width: 560)
    }

    private var usageSection: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(readinessText)
                .font(.headline)
                .foregroundStyle(isAppReady ? .green : .secondary)
                .lineLimit(1)

            Spacer(minLength: 10)

            HStack(alignment: .center, spacing: 10) {
                Text(language.text(.usageStepPermissionsAndModel))
                Text(language.text(.usageStepPromptAndHotkey))
                Text(language.text(.usageStepRewrite))
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language.text(.api))
                    .font(.headline)
                Spacer(minLength: 12)
                Picker("", selection: $store.modelProvider) {
                    ForEach(ModelProvider.allCases) { provider in
                        Text(provider.title(language: language)).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: controlWidth)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            HStack(alignment: .top, spacing: 16) {
                modelProviderLeftColumn
                .frame(maxWidth: .infinity)

                modelPickerColumn
            }
        }
        .disabled(store.isBusy)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var modelProviderLeftColumn: some View {
        if store.modelProvider == .customEndpoint {
            VStack(alignment: .leading, spacing: 10) {
                TextField(language.text(.endpointURL), text: $store.endpointURL)
                    .textFieldStyle(.roundedBorder)
                SecureField(language.text(.apiKey), text: $store.apiKey)
                    .textFieldStyle(.roundedBorder)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button(language.text(.requestAuthorization)) {
                        Task { await store.authorizeGitHubCopilot() }
                    }
                    .disabled(hasGitHubAccount)

                    Button(language.text(.logout)) {
                        store.logoutGitHubCopilot()
                    }
                    .disabled(!hasGitHubAccount)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(language.text(.currentAccount))：\(store.githubAccountLogin.isEmpty ? language.text(.notAuthorized) : store.githubAccountLogin)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var hasGitHubAccount: Bool {
        !store.githubAccountLogin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var modelPickerColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(language.text(.currentModel), selection: $store.selectedModel) {
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
            .frame(width: modelColumnWidth, alignment: .trailing)
            HStack {
                Spacer(minLength: 0)
                Button(language.text(.loadModels)) {
                    Task { await store.loadModels() }
                }
                Button(language.text(.testModel)) {
                    Task { await store.testConnection() }
                }
            }
        }
        .frame(width: modelColumnWidth, alignment: .trailing)
    }

    private var promptAndHotkeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                HStack {
                    Text(language.text(.hotkeyAndPrompt))
                        .font(.headline)
                    Spacer(minLength: 12)
                    HotkeyRecorder(hotkey: $store.hotkey)
                        .frame(width: hotkeyControlWidth, height: 28)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("", selection: $store.rewriteMode) {
                    ForEach(RewriteMode.allCases) { mode in
                        Text(mode.title(language: language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: controlWidth)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .onChange(of: store.rewriteMode) {
                if store.rewriteMode == .custom {
                    store.systemPrompt = ""
                }
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var permissionsSection: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(language.text(.permissions))
                .font(.headline)
            Spacer(minLength: 8)
            Button(language.text(.checkPermissions)) {
                let message = PermissionManager.keyboardPermissionSummary(language: language)
                store.statusMessage = message
                store.addLog(message)
            }
            Button(language.text(.requestAccessibility)) {
                _ = PermissionManager.requestAccessibilityAccess(language: language)
                let message = PermissionManager.keyboardPermissionSummary(language: language)
                store.statusMessage = message
                store.addLog(message)
            }
            Button(language.text(.requestInputMonitoring)) {
                _ = PermissionManager.requestInputMonitoringAccess(language: language)
                let message = PermissionManager.keyboardPermissionSummary(language: language)
                store.statusMessage = message
                store.addLog(message)
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

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                otherFeaturesSection
                Spacer(minLength: 12)
                Text(store.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                Button(language.text(.saveAll)) {
                    store.saveAllSections()
                    onSave()
                }
            }

            if store.showLogs {
                Divider()
                logSection
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Toggle(language.text(.previewFeature), isOn: $store.previewEnabled)
                    .toggleStyle(.checkbox)
                    .onChange(of: store.previewEnabled) {
                        store.saveConfig()
                        onSave()
                    }

                Spacer(minLength: 12)

                if !DictationWorkflow.isAppleSilicon {
                    Text(language.text(.appleSiliconOnly))
                        .foregroundStyle(.secondary)
                }
            }

            if store.previewEnabled {
                if DictationWorkflow.isAppleSilicon {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 12) {
                            Text(language.text(.dictationHotkey))
                                .font(.headline)
                            Spacer()
                            HotkeyRecorder(hotkey: $store.dictationHotkey)
                                .frame(width: hotkeyControlWidth, height: 28)
                                .onChange(of: store.dictationHotkey) {
                                    store.saveConfig()
                                    onSave()
                                }
                            Picker("", selection: $store.whisperModel) {
                                Text("Base").tag("base")
                                Text("Small").tag("small")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: controlWidth * 0.55)
                            .onChange(of: store.whisperModel) {
                                store.saveConfig()
                                onSave()
                            }

                            Button(language.text(.prepareWhisperModel)) {
                                dictationWorkflow?.prepareModel()
                            }
                            .fixedSize(horizontal: true, vertical: false)

                            Button(language.text(.deleteWhisperModel)) {
                                dictationWorkflow?.deleteCurrentModel()
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }

                        if !store.whisperPreparationStatus.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .center, spacing: 10) {
                                    Text(store.whisperPreparationStatus)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(language.text(.downloadProgress)) \(progressPercent(store.whisperDownloadProgress))% · \(language.text(.prepareProgress)) \(progressPercent(store.whisperPreparationProgress))%")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                HStack(alignment: .center, spacing: 10) {
                                    ProgressView(value: store.whisperDownloadProgress)
                                    ProgressView(value: store.whisperPreparationProgress)
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                } else {
                    Text(language.text(.appleSiliconOnly))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func progressPercent(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }

    private var otherFeaturesSection: some View {
        HStack(alignment: .center, spacing: 10) {
            Toggle(language.text(.showStatusBarIcon), isOn: $store.statusBarIconEnabled)
                .toggleStyle(.checkbox)
                .onChange(of: store.statusBarIconEnabled) {
                    store.statusBarIconPreferenceSaved = true
                    store.saveConfig()
                    onSave()
                }

            Toggle(language.text(.showLogs), isOn: $store.showLogs)
                .toggleStyle(.checkbox)

            Picker("", selection: $store.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 92)

            Button(language.text(.checkForUpdates)) {
                store.statusMessage = language == .zhHans ? "正在检查更新..." : "Checking for updates..."
                store.addLog(store.statusMessage)
                UpdateManager.shared.checkForUpdates()
            }
        }
    }
}
