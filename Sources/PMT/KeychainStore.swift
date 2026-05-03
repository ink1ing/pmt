import Foundation
import Security

enum KeychainStore {
    private static let service = "PMT"
    private static let apiKeyAccount = "api-key"

    static func readAPIKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]

        let update: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess {
            return
        }

        if status == errSecItemNotFound {
            var create = query
            create[kSecValueData as String] = data
            let createStatus = SecItemAdd(create as CFDictionary, nil)
            guard createStatus == errSecSuccess else {
                throw PMTError.keychain("Keychain 保存失败：\(createStatus)")
            }
            return
        }

        throw PMTError.keychain("Keychain 更新失败：\(status)")
    }
}
