import AppKit
import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case zhHans
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zhHans:
            "zh"
        case .english:
            "en"
        }
    }

    func text(_ key: LocalizedKey) -> String {
        switch (self, key) {
        case (.zhHans, .api): "模型"
        case (.english, .api): "Model"
        case (.zhHans, .customEndpoint): "OpenAI 兼容"
        case (.english, .customEndpoint): "OpenAI Compatible"
        case (.zhHans, .githubOAuth): "GitHub 认证"
        case (.english, .githubOAuth): "GitHub Auth"
        case (.zhHans, .endpointURL): "端点 URL"
        case (.english, .endpointURL): "Endpoint URL"
        case (.zhHans, .apiKey): "API"
        case (.english, .apiKey): "API"
        case (.zhHans, .requestAuthorization): "请求授权"
        case (.english, .requestAuthorization): "Authorize"
        case (.zhHans, .logout): "退出登录"
        case (.english, .logout): "Log Out"
        case (.zhHans, .currentAccount): "当前账号"
        case (.english, .currentAccount): "Current Account"
        case (.zhHans, .notAuthorized): "未授权"
        case (.english, .notAuthorized): "Not authorized"
        case (.zhHans, .model): "模型"
        case (.english, .model): "Model"
        case (.zhHans, .currentModel): "当前模型"
        case (.english, .currentModel): "Current Model"
        case (.zhHans, .unselected): "未选择"
        case (.english, .unselected): "Not selected"
        case (.zhHans, .loadModels): "读取模型"
        case (.english, .loadModels): "Load Models"
        case (.zhHans, .testModel): "测试模型"
        case (.english, .testModel): "Test Model"
        case (.zhHans, .manualModelID): "手动模型 ID"
        case (.english, .manualModelID): "Manual Model ID"
        case (.zhHans, .saveAPI): "保存 API"
        case (.english, .saveAPI): "Save API"
        case (.zhHans, .prompt): "提示词"
        case (.english, .prompt): "Prompt"
        case (.zhHans, .savePrompt): "保存 Prompt"
        case (.english, .savePrompt): "Save Prompt"
        case (.zhHans, .hotkey): "快捷键"
        case (.english, .hotkey): "Hotkey"
        case (.zhHans, .hotkeyAndPrompt): "快捷键和提示词"
        case (.english, .hotkeyAndPrompt): "Hotkey and Prompt"
        case (.zhHans, .restoreControlX): "恢复 Ctrl + X"
        case (.english, .restoreControlX): "Reset to Ctrl + X"
        case (.zhHans, .saveHotkey): "保存快捷键"
        case (.english, .saveHotkey): "Save Hotkey"
        case (.zhHans, .statusBar): "状态栏"
        case (.english, .statusBar): "Status Bar"
        case (.zhHans, .showStatusBarIcon): "顶部图标"
        case (.english, .showStatusBarIcon): "Bar Icon"
        case (.zhHans, .permissions): "权限"
        case (.english, .permissions): "Permissions"
        case (.zhHans, .checkPermissions): "检查权限"
        case (.english, .checkPermissions): "Check Permissions"
        case (.zhHans, .requestAccessibility): "请求辅助功能权限"
        case (.english, .requestAccessibility): "Request Accessibility"
        case (.zhHans, .requestInputMonitoring): "请求输入监控权限"
        case (.english, .requestInputMonitoring): "Request Input Monitoring"
        case (.zhHans, .checkKeyboardPermissions): "检查键盘权限"
        case (.english, .checkKeyboardPermissions): "Check Keyboard Permissions"
        case (.zhHans, .restartHotkeyMonitor): "重启热键监听"
        case (.english, .restartHotkeyMonitor): "Restart Hotkey Monitor"
        case (.zhHans, .showLogs): "日志"
        case (.english, .showLogs): "Logs"
        case (.zhHans, .checkForUpdates): "检查更新"
        case (.english, .checkForUpdates): "Check for Updates"
        case (.zhHans, .logs): "日志"
        case (.english, .logs): "Logs"
        case (.zhHans, .clear): "清空"
        case (.english, .clear): "Clear"
        case (.zhHans, .language): "语言"
        case (.english, .language): "Language"
        case (.zhHans, .otherFeatures): "其他功能"
        case (.english, .otherFeatures): "Other Features"
        case (.zhHans, .saveLanguage): "保存语言"
        case (.english, .saveLanguage): "Save Language"
        case (.zhHans, .saveAll): "保存"
        case (.english, .saveAll): "Save"
        case (.zhHans, .usage): "使用说明"
        case (.english, .usage): "Usage"
        case (.zhHans, .usageStepPermissionsAndModel): "1. 配置权限和模型"
        case (.english, .usageStepPermissionsAndModel): "1. Permissions/model"
        case (.zhHans, .usageStepPromptAndHotkey): "2. 配置快捷键和提示词"
        case (.english, .usageStepPromptAndHotkey): "2. Hotkey/prompt"
        case (.zhHans, .usageStepRewrite): "3. 选中文字，按下快捷键改写"
        case (.english, .usageStepRewrite): "3. Select + rewrite"
        }
    }
}

enum LocalizedKey {
    case api, customEndpoint, githubOAuth, endpointURL, apiKey, requestAuthorization, logout, currentAccount, notAuthorized
    case model, currentModel, unselected, loadModels, testModel, manualModelID, saveAPI
    case prompt, savePrompt
    case hotkey, hotkeyAndPrompt, restoreControlX, saveHotkey
    case statusBar, showStatusBarIcon
    case permissions, checkPermissions, requestAccessibility, requestInputMonitoring
    case checkKeyboardPermissions, restartHotkeyMonitor
    case showLogs, checkForUpdates, logs, clear
    case language, otherFeatures, saveLanguage, saveAll
    case usage, usageStepPermissionsAndModel, usageStepPromptAndHotkey, usageStepRewrite
}

enum ModelProvider: String, CaseIterable, Codable, Identifiable {
    case customEndpoint
    case githubOAuth

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .customEndpoint:
            language.text(.customEndpoint)
        case .githubOAuth:
            language.text(.githubOAuth)
        }
    }
}

enum RewriteMode: String, CaseIterable, Codable, Identifiable {
    case concise
    case standard
    case custom

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch (language, self) {
        case (.zhHans, .concise):
            "谨慎"
        case (.english, .concise):
            "Cautious"
        case (.zhHans, .standard):
            "精确"
        case (.english, .standard):
            "Precise"
        case (.zhHans, .custom):
            "自定义"
        case (.english, .custom):
            "Custom"
        }
    }

    var builtInPrompt: String? {
        switch self {
        case .concise:
            """
            你是一个提示词重写专家，负责将用户输入的提示词进行规范化改写。

            你的目标是在不改变原始意图的前提下，将提示词转化为清晰、结构化且更安全、规范的指令，从而提升大模型的理解稳定性与执行安全性。

            改写时需遵守以下原则：

            1. 严格保留原始意图，不改变用户的核心需求。
            2. 不新增任何额外需求、假设或隐含任务。
            3. 优化表达，使指令清晰、明确、无歧义，避免歧义或过度开放的描述。
            4. 对内容进行结构化整理，使其具备清晰的逻辑层次（如目标、上下文、约束、输出要求等），但仅基于原内容重组。
            5. 若原提示词可能导致不安全、不合规或高风险输出，应对表达进行约束性收紧（如增加限定条件或收窄范围），但不得改变原始任务本身。
            6. 若原提示词信息不足或存在歧义，优先保持保守表达，不主动补全未知信息。
            7. 统一语气为稳定、可执行的指令风格，避免情绪化或随意表达。
            8. 控制篇幅，在保证清晰与安全的前提下避免冗长。
            """
        case .standard:
            """
            你是一个提示词重写专家，负责将用户输入的提示词进行规范化改写。

            你的目标是将模糊或不清晰的请求转化为简洁、明确、结构合理的指令，从而提升大模型的理解效率和输出质量。

            改写时需遵守以下原则：

            1. 保持原始意图，不改变用户需求本身。
            2. 不新增任何额外需求或隐含任务。
            3. 优化表达，使指令更直接、清晰、无歧义。
            4. 在必要时进行最小限度的结构整理，使内容更有条理，但不过度展开。
            5. 控制篇幅，优先保证简洁性。

            仅输出改写后的提示词，不要附加解释或其他内容。
            """
        case .custom:
            nil
        }
    }
}

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt16
    var carbonModifiers: UInt32
    var secondaryKeyCode: UInt16?
    var displayName: String

    static let defaultControlX = HotkeyConfig(
        keyCode: 7,
        carbonModifiers: 1 << 3,
        secondaryKeyCode: nil,
        displayName: "⌃X"
    )

    static let legacyTabA = HotkeyConfig(
        keyCode: 48,
        carbonModifiers: 0,
        secondaryKeyCode: 0,
        displayName: "Tab + A"
    )

    func matches(keyCode incomingKeyCode: UInt16, flags: CGEventFlags) -> Bool {
        incomingKeyCode == keyCode && Self.carbonModifiers(from: flags) == carbonModifiers
    }

    func matchesSecondary(keyCode incomingKeyCode: UInt16) -> Bool {
        secondaryKeyCode == incomingKeyCode
    }

    static func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.maskCommand) { modifiers |= 1 << 0 }
        if flags.contains(.maskShift) { modifiers |= 1 << 1 }
        if flags.contains(.maskAlternate) { modifiers |= 1 << 2 }
        if flags.contains(.maskControl) { modifiers |= 1 << 3 }
        return modifiers
    }

    static func displayName(keyCode: UInt16, carbonModifiers: UInt32) -> String {
        var parts: [String] = []
        if carbonModifiers & (1 << 0) != 0 { parts.append("⌘") }
        if carbonModifiers & (1 << 1) != 0 { parts.append("⇧") }
        if carbonModifiers & (1 << 2) != 0 { parts.append("⌥") }
        if carbonModifiers & (1 << 3) != 0 { parts.append("⌃") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    static func chordDisplayName(
        keyCode: UInt16,
        carbonModifiers: UInt32,
        secondaryKeyCode: UInt16?
    ) -> String {
        let first = displayName(keyCode: keyCode, carbonModifiers: carbonModifiers)
        guard let secondaryKeyCode else {
            return first
        }
        return "\(first) + \(keyName(for: secondaryKeyCode))"
    }

    static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: "A"
        case 1: "S"
        case 2: "D"
        case 3: "F"
        case 4: "H"
        case 5: "G"
        case 6: "Z"
        case 7: "X"
        case 8: "C"
        case 9: "V"
        case 11: "B"
        case 12: "Q"
        case 13: "W"
        case 14: "E"
        case 15: "R"
        case 16: "Y"
        case 17: "T"
        case 18: "1"
        case 19: "2"
        case 20: "3"
        case 21: "4"
        case 22: "6"
        case 23: "5"
        case 24: "="
        case 25: "9"
        case 26: "7"
        case 27: "-"
        case 28: "8"
        case 29: "0"
        case 30: "]"
        case 31: "O"
        case 32: "U"
        case 33: "["
        case 34: "I"
        case 35: "P"
        case 36: "Return"
        case 37: "L"
        case 38: "J"
        case 39: "'"
        case 40: "K"
        case 41: ";"
        case 42: "\\"
        case 43: ","
        case 44: "/"
        case 45: "N"
        case 46: "M"
        case 47: "."
        case 48: "Tab"
        case 49: "Space"
        case 51: "Delete"
        case 53: "Esc"
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        default: "Key \(keyCode)"
        }
    }

    enum CodingKeys: String, CodingKey {
        case keyCode
        case carbonModifiers
        case secondaryKeyCode
        case displayName
    }

    init(
        keyCode: UInt16,
        carbonModifiers: UInt32,
        secondaryKeyCode: UInt16?,
        displayName: String
    ) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.secondaryKeyCode = secondaryKeyCode
        self.displayName = displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        carbonModifiers = try container.decode(UInt32.self, forKey: .carbonModifiers)
        secondaryKeyCode = try container.decodeIfPresent(UInt16.self, forKey: .secondaryKeyCode)
        let decodedDisplayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        displayName = decodedDisplayName ?? Self.chordDisplayName(
            keyCode: keyCode,
            carbonModifiers: carbonModifiers,
            secondaryKeyCode: secondaryKeyCode
        )
    }
}

struct AppConfig: Codable {
    var modelProvider: ModelProvider
    var endpointURL: String
    var apiKey: String
    var githubOAuthToken: String
    var githubAccountLogin: String
    var selectedModel: String
    var systemPrompt: String
    var rewriteMode: RewriteMode
    var hotkey: HotkeyConfig
    var statusBarIconEnabled: Bool
    var language: AppLanguage

    enum CodingKeys: String, CodingKey {
        case modelProvider
        case endpointURL
        case apiKey
        case githubOAuthToken
        case githubAccountLogin
        case selectedModel
        case systemPrompt
        case rewriteMode
        case hotkey
        case statusBarIconEnabled
        case language
    }

    init(
        modelProvider: ModelProvider,
        endpointURL: String,
        apiKey: String,
        githubOAuthToken: String,
        githubAccountLogin: String,
        selectedModel: String,
        systemPrompt: String,
        rewriteMode: RewriteMode,
        hotkey: HotkeyConfig,
        statusBarIconEnabled: Bool,
        language: AppLanguage
    ) {
        self.modelProvider = modelProvider
        self.endpointURL = endpointURL
        self.apiKey = apiKey
        self.githubOAuthToken = githubOAuthToken
        self.githubAccountLogin = githubAccountLogin
        self.selectedModel = selectedModel
        self.systemPrompt = systemPrompt
        self.rewriteMode = rewriteMode
        self.hotkey = hotkey
        self.statusBarIconEnabled = statusBarIconEnabled
        self.language = language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modelProvider = try container.decodeIfPresent(ModelProvider.self, forKey: .modelProvider) ?? .customEndpoint
        endpointURL = try container.decode(String.self, forKey: .endpointURL)
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        githubOAuthToken = try container.decodeIfPresent(String.self, forKey: .githubOAuthToken) ?? ""
        githubAccountLogin = try container.decodeIfPresent(String.self, forKey: .githubAccountLogin) ?? ""
        selectedModel = try container.decode(String.self, forKey: .selectedModel)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        rewriteMode = try container.decode(RewriteMode.self, forKey: .rewriteMode)
        hotkey = try container.decode(HotkeyConfig.self, forKey: .hotkey)
        statusBarIconEnabled = try container.decodeIfPresent(Bool.self, forKey: .statusBarIconEnabled) ?? true
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .zhHans
    }

    static let defaults = AppConfig(
        modelProvider: .customEndpoint,
        endpointURL: "https://api.openai.com/v1",
        apiKey: "",
        githubOAuthToken: "",
        githubAccountLogin: "",
        selectedModel: "",
        systemPrompt: RewriteMode.standard.builtInPrompt ?? "",
        rewriteMode: .standard,
        hotkey: .defaultControlX,
        statusBarIconEnabled: true,
        language: .zhHans
    )
}
