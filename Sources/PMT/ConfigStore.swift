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
    @Published var availableModels: [String] = []
    @Published var statusMessage: String = ""
    @Published var isBusy = false
    @Published var logs: [LogEntry] = []

    private let defaultsKey = "PMT.config"
    private let logsKey = "PMT.logs"
    private let defaults: UserDefaults
    private let maxLogCount = 120

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

        endpointURL = config.endpointURL
        apiKey = KeychainStore.readAPIKey()
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
            save()
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
            statusBarIconEnabled: statusBarIconEnabled
        )
    }

    func save() {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: defaultsKey)
            defaults.synchronize()
        }
        do {
            try KeychainStore.saveAPIKey(apiKey)
            addLog("配置已保存")
        } catch {
            statusMessage = error.localizedDescription
            addLog("配置保存失败：\(error.localizedDescription)")
        }
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
        statusMessage = "日志已清空"
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
        statusMessage = "读取模型中..."
        addLog("开始读取模型列表")
        defer { isBusy = false }

        do {
            let models = try await apiClient().listModels()
            availableModels = models
            if selectedModel.isEmpty, let first = models.first {
                selectedModel = first
            }
            save()
            statusMessage = "模型读取成功"
            addLog("模型读取成功：\(models.count) 个")
        } catch {
            statusMessage = error.localizedDescription
            addLog("模型读取失败：\(error.localizedDescription)")
            Notifier.shared.error(error.localizedDescription)
        }
    }

    func testConnection() async {
        isBusy = true
        statusMessage = "测试连接中..."
        addLog("开始测试 API 连接")
        defer { isBusy = false }

        do {
            let models = try await apiClient().listModels()
            availableModels = models
            statusMessage = "连接成功，读取到 \(models.count) 个模型"
            save()
            addLog("API 连接成功：读取到 \(models.count) 个模型")
        } catch {
            statusMessage = error.localizedDescription
            addLog("API 连接失败：\(error.localizedDescription)")
            Notifier.shared.error(error.localizedDescription)
        }
    }
}
