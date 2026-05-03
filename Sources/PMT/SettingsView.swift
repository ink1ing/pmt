import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    let onSave: () -> Void

    private var language: AppLanguage { store.language }
    private let controlWidth: CGFloat = 240
    private let hotkeyControlWidth: CGFloat = 60
    private let modelColumnWidth: CGFloat = 240
    @State private var showUsage = false
    @State private var showOtherFeatures = false

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
            permissionsSection
            Divider()
            HStack(alignment: .bottom) {
                otherFeaturesSection
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
        DisclosureGroup(isExpanded: $showUsage) {
            VStack(alignment: .leading, spacing: 8) {
                Text(language.text(.usageStepPermissionsAndModel))
                Text(language.text(.usageStepPromptAndHotkey))
                Text(language.text(.usageStepRewrite))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack {
                Text(language.text(.usage))
                    .font(.headline)
                Spacer(minLength: 12)
                Text(store.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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
            HStack(alignment: .top, spacing: 16) {
                modelProviderLeftColumn
                .frame(maxWidth: .infinity)

                modelPickerColumn
            }
        }
        .disabled(store.isBusy)
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

                TextField(
                    language.text(.currentAccount),
                    text: .constant(store.githubAccountLogin.isEmpty ? language.text(.notAuthorized) : store.githubAccountLogin)
                )
                .textFieldStyle(.roundedBorder)
                .disabled(true)
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

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.text(.prompt))
                    .font(.headline)
                Spacer(minLength: 12)
                Picker("", selection: $store.rewriteMode) {
                    ForEach(RewriteMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: controlWidth)
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
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.text(.hotkey))
                    .font(.headline)
                Spacer(minLength: 12)
                HotkeyRecorder(hotkey: $store.hotkey)
                    .frame(width: hotkeyControlWidth, height: 34)
            }
        }
    }

    private var permissionsSection: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(language.text(.permissions))
                .font(.headline)
            Spacer(minLength: 8)
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

    private var otherFeaturesSection: some View {
        DisclosureGroup(isExpanded: $showOtherFeatures) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 0) {
                    Toggle(language.text(.showStatusBarIcon), isOn: $store.statusBarIconEnabled)
                        .toggleStyle(.checkbox)
                    Spacer()
                        .frame(width: 16)
                    Toggle(language.text(.showLogs), isOn: $store.showLogs)
                        .toggleStyle(.checkbox)
                    Picker("", selection: $store.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    Button(language.text(.checkForUpdates)) {
                        store.addLog(language == .zhHans ? "手动检查更新" : "Checking for updates manually")
                        UpdateManager.shared.checkForUpdates()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if store.showLogs {
                    Divider()
                    logSection
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        } label: {
            Text(language.text(.otherFeatures))
                .font(.headline)
        }
    }
}
