import Foundation

/// 直接解析 String Catalog（Localizable.xcstrings）取文案。
/// 纯 `swift build` 不会把 .xcstrings 编译成 .lproj，故以 catalog 为源，运行时解析一次并缓存。
/// App 内中英切换独立于系统语言，按 AppLanguage 选择对应翻译。
enum Localized {
    static func string(_ key: String, _ language: AppLanguage) -> String {
        let code = language == .zhHans ? "zh-Hans" : "en"
        let entry = table[key]
        return entry?[code] ?? entry?["en"] ?? key
    }

    private static let table: [String: [String: String]] = load()

    private static func load() -> [String: [String: String]] {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else {
            return [:]
        }
        return catalog.strings.mapValues { entry in
            entry.localizations.compactMapValues { $0.stringUnit?.value }
        }
    }

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            struct Localization: Decodable {
                struct Unit: Decodable { let value: String }
                let stringUnit: Unit?
            }
            let localizations: [String: Localization]
        }
        let strings: [String: Entry]
    }
}
