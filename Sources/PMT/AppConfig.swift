import AppKit
import Foundation

enum RewriteMode: String, CaseIterable, Codable, Identifiable {
    case concise
    case standard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .concise:
            "简洁"
        case .standard:
            "常规"
        }
    }

    var instruction: String {
        switch self {
        case .concise:
            "Rewrite the selected text into a concise, structured prompt. Keep only necessary sections and remove redundant wording."
        case .standard:
            "Rewrite the selected text into a clear, structured prompt with goal, context, requirements, constraints, and output format where useful."
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
    var endpointURL: String
    var selectedModel: String
    var systemPrompt: String
    var rewriteMode: RewriteMode
    var hotkey: HotkeyConfig
    var statusBarIconEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case endpointURL
        case selectedModel
        case systemPrompt
        case rewriteMode
        case hotkey
        case statusBarIconEnabled
    }

    init(
        endpointURL: String,
        selectedModel: String,
        systemPrompt: String,
        rewriteMode: RewriteMode,
        hotkey: HotkeyConfig,
        statusBarIconEnabled: Bool
    ) {
        self.endpointURL = endpointURL
        self.selectedModel = selectedModel
        self.systemPrompt = systemPrompt
        self.rewriteMode = rewriteMode
        self.hotkey = hotkey
        self.statusBarIconEnabled = statusBarIconEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        endpointURL = try container.decode(String.self, forKey: .endpointURL)
        selectedModel = try container.decode(String.self, forKey: .selectedModel)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        rewriteMode = try container.decode(RewriteMode.self, forKey: .rewriteMode)
        hotkey = try container.decode(HotkeyConfig.self, forKey: .hotkey)
        statusBarIconEnabled = try container.decodeIfPresent(Bool.self, forKey: .statusBarIconEnabled) ?? true
    }

    static let defaults = AppConfig(
        endpointURL: "https://api.openai.com/v1",
        selectedModel: "",
        systemPrompt: """
        You are PMT, a prompt rewriting assistant.
        Rewrite selected user text into a structured prompt that is immediately usable with a large language model.
        Preserve the user's intent, remove ambiguity, and do not add unrelated requirements.
        Return only the rewritten prompt.
        """,
        rewriteMode: .standard,
        hotkey: .defaultControlX,
        statusBarIconEnabled: true
    )
}
