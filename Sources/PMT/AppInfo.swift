import Foundation

enum AppInfo {
    static var shortVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let normalized = version?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized?.isEmpty == false ? normalized! : "0.0.0"
    }

    static var displayVersion: String {
        "v\(shortVersion)"
    }

    static var userAgent: String {
        "PMT/\(shortVersion)"
    }
}
