import AppKit
import Foundation

struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let message: String

    init(id: UUID = UUID(), timestamp: Date = Date(), message: String) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
    }
}

@MainActor
final class ConfigStore: ObservableObject {
    @Published var modelProvider: ModelProvider
    @Published var endpointURL: String
    @Published var apiKey: String
    @Published var githubOAuthToken: String
    @Published var githubAccountLogin: String
    @Published var selectedModel: String
    @Published var systemPrompt: String
    @Published var rewriteMode: RewriteMode
    @Published var hotkey: HotkeyConfig
    @Published var previewEnabled: Bool
    @Published var dictationHotkey: HotkeyConfig
    @Published var whisperModel: String
    @Published var whisperMetalAccelerationEnabled: Bool
    @Published var whisperModelStatus: String = "未准备"
    @Published var whisperDownloadProgress: Double = 0
    @Published var whisperPreparationProgress: Double = 0
    @Published var whisperPreparationStatus: String = ""
    @Published var statusBarIconEnabled: Bool
    @Published var statusBarIconPreferenceSaved: Bool
    @Published var floatingIconVisible = false
    @Published var language: AppLanguage
    @Published var availableModels: [String] = []
    @Published var statusMessage: String = ""
    @Published var isBusy = false
    @Published var logs: [LogEntry] = []
    @Published var showLogs = false

    private let defaultsKey = "PMT.config"
    private let logsKey = "PMT.logs"
    private let defaults: UserDefaults
    private let maxLogCount = 120
    private let floatingIconMigrationKey = "PMT.floatingIconMigration.v1"

    private static let configSuiteName = "dev.pmt.PMT.shared"
    private static let legacyConfigSuiteName = "dev.pmt.PMT"

    init() {
        defaults = UserDefaults(suiteName: Self.configSuiteName) ?? .standard
        let legacyDefaults = UserDefaults(suiteName: Self.legacyConfigSuiteName)

        let config: AppConfig
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = decoded
        } else if let data = legacyDefaults?.data(forKey: defaultsKey),
                  let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = decoded
            defaults.set(data, forKey: defaultsKey)
        } else if let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = decoded
            defaults.set(data, forKey: defaultsKey)
        } else {
            config = .defaults
        }

        modelProvider = config.modelProvider
        endpointURL = config.endpointURL
        apiKey = config.apiKey
        githubOAuthToken = config.githubOAuthToken
        githubAccountLogin = config.githubAccountLogin
        selectedModel = config.selectedModel
        systemPrompt = config.systemPrompt
        rewriteMode = config.rewriteMode
        let shouldMigrateHotkey =
            config.hotkey == .legacyTabA ||
            (config.hotkey.keyCode == 48 &&
             config.hotkey.carbonModifiers == 0 &&
             config.hotkey.secondaryKeyCode == nil)

        if shouldMigrateHotkey {
            hotkey = .defaultControlX
        } else {
            hotkey = config.hotkey
        }
        previewEnabled = config.previewEnabled
        dictationHotkey = config.dictationHotkey
        whisperModel = config.whisperModel
        whisperMetalAccelerationEnabled = true
        let shouldMigrateFloatingIcon = defaults.object(forKey: floatingIconMigrationKey) == nil
        let shouldRestoreDefaultFloatingIcon = !config.statusBarIconPreferenceSaved || shouldMigrateFloatingIcon
        statusBarIconEnabled = shouldRestoreDefaultFloatingIcon ? true : config.statusBarIconEnabled
        statusBarIconPreferenceSaved = config.statusBarIconPreferenceSaved
        language = config.language
        if shouldMigrateFloatingIcon {
            defaults.set(true, forKey: floatingIconMigrationKey)
        }

        if let data = defaults.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            logs = decoded
        } else if let data = legacyDefaults?.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            logs = decoded
            defaults.set(data, forKey: logsKey)
        }

        addLog("应用启动，配置域：\(Self.configSuiteName)")

        if shouldMigrateHotkey {
            saveConfig()
            addLog("已将旧默认快捷键迁移为 Ctrl + X")
        }

        if shouldRestoreDefaultFloatingIcon, !config.statusBarIconEnabled {
            saveConfig()
            addLog("已恢复悬浮图标默认开启")
        }
    }

    var config: AppConfig {
        AppConfig(
            modelProvider: modelProvider,
            endpointURL: endpointURL,
            apiKey: apiKey,
            githubOAuthToken: githubOAuthToken,
            githubAccountLogin: githubAccountLogin,
            selectedModel: selectedModel,
            systemPrompt: systemPrompt,
            rewriteMode: rewriteMode,
            hotkey: hotkey,
            previewEnabled: previewEnabled,
            dictationHotkey: dictationHotkey,
            whisperModel: whisperModel,
            whisperMetalAccelerationEnabled: whisperMetalAccelerationEnabled,
            statusBarIconEnabled: statusBarIconEnabled,
            statusBarIconPreferenceSaved: statusBarIconPreferenceSaved,
            language: language
        )
    }

    func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: defaultsKey)
            defaults.synchronize()
        }
        addLog("配置已保存")
    }

    func saveAPISection() {
        saveConfig()
        statusMessage = language == .zhHans ? "API 配置已保存" : "API settings saved"
        addLog(statusMessage)
    }

    func savePromptSection() {
        if let builtInPrompt = rewriteMode.builtInPrompt {
            systemPrompt = builtInPrompt
        }
        saveConfig()
        statusMessage = language == .zhHans ? "Prompt 配置已保存" : "Prompt settings saved"
        addLog(statusMessage)
    }

    func saveHotkeySection() {
        saveConfig()
        statusMessage = language == .zhHans ? "快捷键配置已保存" : "Hotkey settings saved"
        addLog(statusMessage)
    }

    func saveLanguageSection() {
        saveConfig()
        statusMessage = language == .zhHans ? "语言配置已保存" : "Language settings saved"
        addLog(statusMessage)
    }

    func saveAllSections() {
        if let builtInPrompt = rewriteMode.builtInPrompt {
            systemPrompt = builtInPrompt
        }
        saveConfig()
        statusMessage = language == .zhHans ? "全部配置已保存" : "All settings saved"
        addLog(statusMessage)
    }

    func addLog(_ message: String) {
        NSLog("PMT: %@", message)
        logs.append(LogEntry(message: message))
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }
        persistLogs()
    }

    func clearLogs() {
        logs.removeAll()
        persistLogs()
        statusMessage = language == .zhHans ? "日志已清空" : "Logs cleared"
    }

    func formattedLogLine(_ entry: LogEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: entry.timestamp))] \(entry.message)"
    }

    private func persistLogs() {
        if let data = try? JSONEncoder().encode(logs) {
            defaults.set(data, forKey: logsKey)
            defaults.synchronize()
        }
    }

    func apiClient() throws -> OpenAICompatibleClient {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PMTError.missingAPIKey
        }
        return try OpenAICompatibleClient(endpointURL: endpointURL, apiKey: apiKey)
    }

    func modelClient() throws -> PromptModelClient {
        switch modelProvider {
        case .customEndpoint:
            return try apiClient()
        case .githubOAuth:
            guard !githubOAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PMTError.api(language == .zhHans ? "请先完成 GitHub OAuth 授权。" : "Authorize GitHub OAuth first.")
            }
            return GitHubCopilotClient(accessToken: githubOAuthToken)
        }
    }

    private var activeSystemPrompt: String {
        rewriteMode.builtInPrompt ?? systemPrompt
    }

    func rewrite(text: String) async throws -> String {
        try await modelClient().rewrite(
            text: text,
            model: selectedModel,
            systemPrompt: activeSystemPrompt,
            mode: rewriteMode
        )
    }

    func authorizeGitHubCopilot() async {
        guard githubAccountLogin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = language == .zhHans ? "当前已登录 GitHub 账号" : "GitHub account is already signed in"
            addLog(statusMessage)
            return
        }

        isBusy = true
        statusMessage = language == .zhHans ? "正在请求 GitHub 授权..." : "Requesting GitHub authorization..."
        addLog(language == .zhHans ? "开始 GitHub OAuth 授权" : "Starting GitHub OAuth authorization")
        defer { isBusy = false }

        do {
            let session = try await GitHubCopilotClient.startDeviceFlow()
            statusMessage = language == .zhHans
                ? "请在 GitHub 页面完成授权，验证码：\(session.userCode)"
                : "Complete GitHub authorization. Code: \(session.userCode)"
            addLog(language == .zhHans ? "已打开 GitHub 授权页面，验证码：\(session.userCode)" : "Opened GitHub authorization page. Code: \(session.userCode)")
            NSWorkspace.shared.open(session.verificationURL)

            let account = try await GitHubCopilotClient.pollAuthorization(session: session)
            githubOAuthToken = account.accessToken
            githubAccountLogin = account.login
            modelProvider = .githubOAuth
            saveConfig()
            statusMessage = language == .zhHans ? "GitHub 已授权：\(account.login)" : "GitHub authorized: \(account.login)"
            addLog(statusMessage)
        } catch {
            statusMessage = error.localizedDescription
            addLog(language == .zhHans ? "GitHub 授权失败：\(error.localizedDescription)" : "GitHub authorization failed: \(error.localizedDescription)")
            Notifier.shared.error(error.localizedDescription)
        }
    }

    func logoutGitHubCopilot() {
        guard !githubAccountLogin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
              !githubOAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = language == .zhHans ? "当前没有 GitHub 登录账号" : "No GitHub account is signed in"
            addLog(statusMessage)
            return
        }

        let previousAccount = githubAccountLogin
        githubOAuthToken = ""
        githubAccountLogin = ""
        if modelProvider == .githubOAuth {
            availableModels = []
            selectedModel = ""
        }
        saveConfig()
        statusMessage = language == .zhHans ? "已退出 GitHub：\(previousAccount)" : "GitHub signed out: \(previousAccount)"
        addLog(statusMessage)
    }

    func loadModels() async {
        isBusy = true
        statusMessage = language == .zhHans ? "读取模型中..." : "Loading models..."
        addLog("开始读取模型列表")
        defer { isBusy = false }

        do {
            let models = try await modelClient().listModels()
            availableModels = models
            if selectedModel.isEmpty, let first = models.first {
                selectedModel = first
            }
            saveConfig()
            statusMessage = language == .zhHans ? "模型读取成功" : "Models loaded"
            addLog(language == .zhHans ? "模型读取成功：\(models.count) 个" : "Models loaded: \(models.count)")
        } catch {
            statusMessage = error.localizedDescription
            addLog(language == .zhHans ? "模型读取失败：\(error.localizedDescription)" : "Model loading failed: \(error.localizedDescription)")
            Notifier.shared.error(error.localizedDescription)
        }
    }

    func testConnection() async {
        isBusy = true
        statusMessage = language == .zhHans ? "测试模型中..." : "Testing model..."
        addLog(language == .zhHans ? "开始测试当前模型" : "Testing current model")
        defer { isBusy = false }

        do {
            guard !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PMTError.missingModel
            }

            let elapsed = try await modelClient().testModelLatency(
                model: selectedModel,
                systemPrompt: activeSystemPrompt,
                mode: rewriteMode
            )
            let formatted = String(format: "%.2f", elapsed)
            statusMessage = language == .zhHans ? "模型测试成功，延迟 \(formatted) 秒" : "Model test succeeded, latency \(formatted)s"
            addLog(language == .zhHans ? "模型测试成功：\(selectedModel)，延迟 \(formatted) 秒" : "Model test succeeded: \(selectedModel), latency \(formatted)s")
        } catch {
            statusMessage = error.localizedDescription
            addLog(language == .zhHans ? "模型测试失败：\(error.localizedDescription)" : "Model test failed: \(error.localizedDescription)")
            Notifier.shared.error(error.localizedDescription)
        }
    }
}
