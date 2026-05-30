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
        Localized.string(key.rawValue, self)
    }
}

enum LocalizedKey: String {
    case api, customEndpoint, githubOAuth, endpointURL, apiKey, requestAuthorization, logout, currentAccount, notAuthorized
    case model, currentModel, unselected, loadModels, testModel, manualModelID, saveAPI
    case prompt, savePrompt
    case hotkey, hotkeyAndPrompt, restoreControlX, saveHotkey
    case statusBar, showStatusBarIcon
    case permissions, checkPermissions, requestAccessibility, requestInputMonitoring
    case checkKeyboardPermissions, restartHotkeyMonitor
    case showLogs, checkForUpdates, previewFeature
    case adviceFeature, enableAdvice, adviceFrequency, adviceTime, adviceDetail, advicePath, generateAdviceNow, telegramPush, telegramBotToken, telegramChatID
    case dictationHotkey, whisperModel, downloadProgress, prepareProgress, prepareWhisperModel, deleteWhisperModel, appleSiliconOnly, logs, clear
    case language, otherFeatures, saveLanguage, saveAll, quitApp
    case usage, usageStepPermissionsAndModel, usageStepPromptAndHotkey, usageStepRewrite
    case streamingMode, rewriteNow, preset, settings
    case telegramSetup, telegramSetupTitle, telegramSetupIntro
    case telegramStep1, telegramStep2, telegramStep3, telegramHint
    case telegramFetchChatID, telegramSendTest, done
    case resultTitle, copy, close
    case failureTitle, retry, cancel
}

enum AdviceFrequency: String, CaseIterable, Codable, Identifiable {
    case manual
    case daily
    case weekly

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        Localized.string("adviceFrequency.\(rawValue)", language)
    }
}

enum AdviceDetail: String, CaseIterable, Codable, Identifiable {
    case minimal
    case brief
    case standard

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        Localized.string("adviceDetail.\(rawValue)", language)
    }

    var targetDescription: String {
        switch self {
        case .minimal:
            "最多给出 1 条最高价值的改进；若无明显问题，只保留一句话总评。"
        case .brief:
            "最多给出 2 条改进，按影响力排序；若无明显问题则省略改进项。"
        case .standard:
            "最多给出 3 条改进，可在末尾附 1 条做得好的点；若无明显问题则明确写明无需调整。"
        }
    }
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
        Localized.string("rewriteMode.\(rawValue)", language)
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

            输出要求：
            1. 仅输出改写后的提示词本身。
            2. 不要添加任何解释、说明、总结、标题或对话式回应。
            3. 不要输出“以下是提示词改写结果”“下面是改好的提示词”等引导语。
            4. 不要使用 Markdown 语法格式，包括但不限于标题、列表符号、加粗、代码块或引用块。
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

            输出要求：
            1. 仅输出改写后的提示词本身。
            2. 不要添加任何解释、说明、总结、标题或对话式回应。
            3. 不要输出“以下是提示词改写结果”“下面是改好的提示词”等引导语。
            4. 不要使用 Markdown 语法格式，包括但不限于标题、列表符号、加粗、代码块或引用块。
            """
        case .custom:
            nil
        }
    }
}

struct RewritePreset: Codable, Equatable {
    var model: String
    var rewriteMode: RewriteMode
    var systemPrompt: String
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

    static let defaultControlD = HotkeyConfig(
        keyCode: 2,
        carbonModifiers: 1 << 3,
        secondaryKeyCode: nil,
        displayName: "⌃D"
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
    var githubAccountLogin: String
    var selectedModel: String
    var systemPrompt: String
    var rewriteMode: RewriteMode
    var hotkey: HotkeyConfig
    var streamingEnabled: Bool
    var presets: [RewritePreset]
    var activePresetIndex: Int
    var previewEnabled: Bool
    var dictationHotkey: HotkeyConfig
    var whisperModel: String
    var whisperMetalAccelerationEnabled: Bool
    var adviceEnabled: Bool
    var adviceFrequency: AdviceFrequency
    var adviceHour: Int
    var adviceMinute: Int
    var adviceDetail: AdviceDetail
    var adviceFilePath: String
    var telegramPushEnabled: Bool
    var telegramChatID: String
    var lastAdviceGeneratedAt: Date?
    var floatingIconEnabled: Bool
    var floatingIconPreferenceSaved: Bool
    var language: AppLanguage

    enum CodingKeys: String, CodingKey {
        case modelProvider
        case endpointURL
        case githubAccountLogin
        case selectedModel
        case systemPrompt
        case rewriteMode
        case hotkey
        case streamingEnabled
        case presets
        case activePresetIndex
        case previewEnabled
        case dictationHotkey
        case whisperModel
        case whisperMetalAccelerationEnabled
        case adviceEnabled
        case adviceFrequency
        case adviceHour
        case adviceMinute
        case adviceDetail
        case adviceFilePath
        case telegramPushEnabled
        case telegramChatID
        case lastAdviceGeneratedAt
        case floatingIconEnabled = "statusBarIconEnabled"
        case floatingIconPreferenceSaved = "statusBarIconPreferenceSaved"
        case language
    }

    init(
        modelProvider: ModelProvider,
        endpointURL: String,
        githubAccountLogin: String,
        selectedModel: String,
        systemPrompt: String,
        rewriteMode: RewriteMode,
        hotkey: HotkeyConfig,
        streamingEnabled: Bool,
        presets: [RewritePreset],
        activePresetIndex: Int,
        previewEnabled: Bool,
        dictationHotkey: HotkeyConfig,
        whisperModel: String,
        whisperMetalAccelerationEnabled: Bool,
        adviceEnabled: Bool,
        adviceFrequency: AdviceFrequency,
        adviceHour: Int,
        adviceMinute: Int,
        adviceDetail: AdviceDetail,
        adviceFilePath: String,
        telegramPushEnabled: Bool,
        telegramChatID: String,
        lastAdviceGeneratedAt: Date?,
        floatingIconEnabled: Bool,
        floatingIconPreferenceSaved: Bool,
        language: AppLanguage
    ) {
        self.modelProvider = modelProvider
        self.endpointURL = endpointURL
        self.githubAccountLogin = githubAccountLogin
        self.selectedModel = selectedModel
        self.systemPrompt = systemPrompt
        self.rewriteMode = rewriteMode
        self.hotkey = hotkey
        self.streamingEnabled = streamingEnabled
        self.presets = presets
        self.activePresetIndex = activePresetIndex
        self.previewEnabled = previewEnabled
        self.dictationHotkey = dictationHotkey
        self.whisperModel = whisperModel
        self.whisperMetalAccelerationEnabled = whisperMetalAccelerationEnabled
        self.adviceEnabled = adviceEnabled
        self.adviceFrequency = adviceFrequency
        self.adviceHour = adviceHour
        self.adviceMinute = adviceMinute
        self.adviceDetail = adviceDetail
        self.adviceFilePath = adviceFilePath
        self.telegramPushEnabled = telegramPushEnabled
        self.telegramChatID = telegramChatID
        self.lastAdviceGeneratedAt = lastAdviceGeneratedAt
        self.floatingIconEnabled = floatingIconEnabled
        self.floatingIconPreferenceSaved = floatingIconPreferenceSaved
        self.language = language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modelProvider = try container.decodeIfPresent(ModelProvider.self, forKey: .modelProvider) ?? .customEndpoint
        endpointURL = try container.decodeIfPresent(String.self, forKey: .endpointURL) ?? Self.defaults.endpointURL
        githubAccountLogin = try container.decodeIfPresent(String.self, forKey: .githubAccountLogin) ?? ""
        selectedModel = try container.decodeIfPresent(String.self, forKey: .selectedModel) ?? Self.defaults.selectedModel
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? Self.defaults.systemPrompt
        rewriteMode = try container.decodeIfPresent(RewriteMode.self, forKey: .rewriteMode) ?? Self.defaults.rewriteMode
        hotkey = try container.decodeIfPresent(HotkeyConfig.self, forKey: .hotkey) ?? Self.defaults.hotkey
        streamingEnabled = try container.decodeIfPresent(Bool.self, forKey: .streamingEnabled) ?? false
        let basePreset = RewritePreset(model: selectedModel, rewriteMode: rewriteMode, systemPrompt: systemPrompt)
        var decodedPresets = try container.decodeIfPresent([RewritePreset].self, forKey: .presets) ?? [basePreset, basePreset, basePreset]
        if decodedPresets.isEmpty { decodedPresets = [basePreset, basePreset, basePreset] }
        while decodedPresets.count < 3 { decodedPresets.append(basePreset) }
        if decodedPresets.count > 3 { decodedPresets = Array(decodedPresets.prefix(3)) }
        presets = decodedPresets
        let decodedIndex = try container.decodeIfPresent(Int.self, forKey: .activePresetIndex) ?? 0
        activePresetIndex = min(max(decodedIndex, 0), decodedPresets.count - 1)
        previewEnabled = try container.decodeIfPresent(Bool.self, forKey: .previewEnabled) ?? false
        dictationHotkey = try container.decodeIfPresent(HotkeyConfig.self, forKey: .dictationHotkey) ?? .defaultControlD
        whisperModel = try container.decodeIfPresent(String.self, forKey: .whisperModel) ?? "base"
        whisperMetalAccelerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .whisperMetalAccelerationEnabled) ?? true
        adviceEnabled = try container.decodeIfPresent(Bool.self, forKey: .adviceEnabled) ?? false
        adviceFrequency = try container.decodeIfPresent(AdviceFrequency.self, forKey: .adviceFrequency) ?? .daily
        adviceHour = try container.decodeIfPresent(Int.self, forKey: .adviceHour) ?? 22
        adviceMinute = try container.decodeIfPresent(Int.self, forKey: .adviceMinute) ?? 0
        adviceDetail = try container.decodeIfPresent(AdviceDetail.self, forKey: .adviceDetail) ?? .brief
        adviceFilePath = try container.decodeIfPresent(String.self, forKey: .adviceFilePath) ?? Self.defaultAdviceFilePath
        telegramPushEnabled = try container.decodeIfPresent(Bool.self, forKey: .telegramPushEnabled) ?? false
        telegramChatID = try container.decodeIfPresent(String.self, forKey: .telegramChatID) ?? ""
        lastAdviceGeneratedAt = try container.decodeIfPresent(Date.self, forKey: .lastAdviceGeneratedAt)
        floatingIconEnabled = try container.decodeIfPresent(Bool.self, forKey: .floatingIconEnabled) ?? true
        floatingIconPreferenceSaved = try container.decodeIfPresent(Bool.self, forKey: .floatingIconPreferenceSaved) ?? false
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .zhHans
    }

    static let defaults = AppConfig(
        modelProvider: .customEndpoint,
        endpointURL: "https://api.openai.com/v1",
        githubAccountLogin: "",
        selectedModel: "",
        systemPrompt: RewriteMode.standard.builtInPrompt ?? "",
        rewriteMode: .standard,
        hotkey: .defaultControlX,
        streamingEnabled: false,
        presets: Array(
            repeating: RewritePreset(model: "", rewriteMode: .standard, systemPrompt: RewriteMode.standard.builtInPrompt ?? ""),
            count: 3
        ),
        activePresetIndex: 0,
        previewEnabled: false,
        dictationHotkey: .defaultControlD,
        whisperModel: "base",
        whisperMetalAccelerationEnabled: true,
        adviceEnabled: false,
        adviceFrequency: .daily,
        adviceHour: 22,
        adviceMinute: 0,
        adviceDetail: .brief,
        adviceFilePath: AppConfig.defaultAdviceFilePath,
        telegramPushEnabled: false,
        telegramChatID: "",
        lastAdviceGeneratedAt: nil,
        floatingIconEnabled: true,
        floatingIconPreferenceSaved: false,
        language: .zhHans
    )

    static var defaultAdviceFilePath: String {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appending(path: "Documents/PMT/advice.md")
            .path
    }
}
