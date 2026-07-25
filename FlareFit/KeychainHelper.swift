//
//  KeychainHelper.swift
//  FlareFit
//

import Foundation
import Security

/// Minimal Keychain wrapper for storing the user's API keys securely.
enum KeychainHelper {
    private static let service = "net.quietflare.flarefit"
    private static let anthropicAccount = "anthropic-api-key"
    private static let elevenLabsAccount = "elevenlabs-api-key"

    // Anthropic (AI photo-to-plan)
    static func saveAPIKey(_ key: String) { save(key, account: anthropicAccount) }
    static func loadAPIKey() -> String? { load(account: anthropicAccount) }

    // ElevenLabs (natural coach voice)
    static func saveElevenLabsKey(_ key: String) { save(key, account: elevenLabsAccount) }
    static func loadElevenLabsKey() -> String? { load(account: elevenLabsAccount) }

    // MARK: - Internals

    private static func save(_ key: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        guard !key.isEmpty else { return }

        var attributes = query
        attributes[kSecValueData as String] = Data(key.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
