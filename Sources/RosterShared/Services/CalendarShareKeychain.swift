import Foundation
import Security

/// The share write secret lives in the Keychain rather than sqlite: anyone
/// holding it can overwrite the public calendar content. The read token
/// (which is intentionally shareable) stays in UserDefaults.
package enum CalendarShareKeychain {
    private static let service = "com.bearoster.app.calendar-share"
    private static let account = "write-secret"

    package static func saveSecret(_ secret: String) {
        var query = baseQuery
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = Data(secret.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    package static func readSecret() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let secret = String(data: data, encoding: .utf8)
        else { return nil }
        return secret
    }

    package static func deleteSecret() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
