import Foundation
import Security

final class KeychainManager: Sendable {
    private let serviceName = "com.sayit.app"

    enum KeyType: String, CaseIterable {
        case geminiAPIKey = "gemini-api-key"
        case openRouterAPIKey = "openrouter-api-key"
        case claudeAPIKey = "claude-api-key"

        var displayName: String {
            switch self {
            case .geminiAPIKey: return "Gemini API Key"
            case .openRouterAPIKey: return "OpenRouter API Key"
            case .claudeAPIKey: return "Claude API Key"
            }
        }
    }

    func save(key: String, for keyType: KeyType) -> Bool {
        // Delete existing first
        delete(keyType: keyType)

        guard let data = key.data(using: .utf8) else {
            NSLog("[Sayit] KeychainManager: Failed to encode key data for \(keyType.rawValue)")
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyType.rawValue,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("[Sayit] KeychainManager: Save failed for \(keyType.rawValue), OSStatus: \(status)")
        } else {
            NSLog("[Sayit] KeychainManager: Saved \(keyType.rawValue) successfully")
        }
        return status == errSecSuccess
    }

    func retrieve(keyType: KeyType) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyType.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                NSLog("[Sayit] KeychainManager: Retrieve failed for \(keyType.rawValue), OSStatus: \(status)")
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func delete(keyType: KeyType) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyType.rawValue,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    func hasKey(_ keyType: KeyType) -> Bool {
        return retrieve(keyType: keyType) != nil
    }
}
