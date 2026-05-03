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
    @Published var endpointURL: String
    @Published var apiKey: String
    @Published var selectedModel: String
    @Published var systemPrompt: String
    @Published var rewriteMode: RewriteMode
    @Published var hotkey: HotkeyConfig
    @Published var statusBarIconEnabled: Bool
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
    private var lastSavedAPIKey: String

    private static let configSuiteName = "dev.pmt.PMT.shared"
    private static let legacyConfigSuiteName = "dev.pmt.PMT"

    init() {
        defaults = UserDefaults(suiteName: Self.configSuiteName) ?? .standard
        let legacyDefaults = UserDefaults(suiteName: Self.legacyConfigSuiteName)
        let currentAPIKey = KeychainStore.readAPIKey()

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

        endpointURL = config.endpointURL
        apiKey = currentAPIKey
        lastSavedAPIKey = currentAPIKey
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
        statusBarIconEnabled = config.statusBarIconEnabled
        language = config.language

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
    }

    var config: AppConfig {
        AppConfig(
            endpointURL: endpointURL,
            selectedModel: selectedModel,
            systemPrompt: systemPrompt,
            rewriteMode: rewriteMode,
            hotkey: hotkey,
            statusBarIconEnabled: statusBarIconEnabled,
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

    func saveAPIKeyIfNeeded() throws {
        guard apiKey != lastSavedAPIKey else {
            return
        }
        try KeychainStore.saveAPIKey(apiKey)
        lastSavedAPIKey = apiKey
    }

    func saveAPISection() {
        saveConfig()
        do {
            try saveAPIKeyIfNeeded()
            statusMessage = language == .zhHans ? "API 配置已保存" : "API settings saved"
            addLog(statusMessage)
        } catch {
            statusMessage = error.localizedDescription
            addLog(language == .zhHans ? "API 配置保存失败：\(error.localizedDescription)" : "API settings save failed: \(error.localizedDescription)")
        }
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

    func loadModels() async {
        isBusy = true
        statusMessage = language == .zhHans ? "读取模型中..." : "Loading models..."
        addLog("开始读取模型列表")
        defer { isBusy = false }

        do {
            let models = try await apiClient().listModels()
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

            let elapsed = try await apiClient().testModelLatency(
                model: selectedModel,
                systemPrompt: systemPrompt,
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
