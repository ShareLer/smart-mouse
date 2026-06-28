import Foundation
import Security

enum KeychainManager {
    private static let service = "com.smartmouse.llm"

    @discardableResult
    static func save(apiKey: String) -> Bool {
        guard let data = apiKey.data(using: .utf8) else { return false }

        let base: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]

        // Try update first (if item exists)
        let update: [CFString: Any] = [kSecValueData: data]
        var status = SecItemUpdate(base as CFDictionary, update as CFDictionary)

        if status == errSecItemNotFound {
            // Try add (first-time)
            var addQuery = base
            addQuery[kSecValueData] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        return status == errSecSuccess
    }

    static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8)
        else { return nil }

        return apiKey
    }

    @discardableResult
    static func delete() -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
