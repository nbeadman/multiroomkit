import Foundation
import Security
import Darwin

public enum CredentialStore {
    private static let service = "org.multiroomkit.prototype.speaker-status"
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    private static func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query(account)
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw StatusError("Could not save credentials in Keychain.") }
        } else if status != errSecSuccess { throw StatusError("Could not update credentials in Keychain.") }
    }
    private static func read(_ account: String) throws -> String {
        var item = query(account)
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(item as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw StatusError("Cloud credentials are not available in Keychain. See README cloud setup, then run cloud-status --set-credentials. Never paste credentials into chat or GitHub.")
        }
        return value
    }
    public static func load() throws -> CloudCredentials {
        try CloudCredentials(token: read("access-token"), apiKey: read("api-key"))
    }
    public static func promptAndSave() throws {
        guard isatty(STDIN_FILENO) == 1 else { throw StatusError("Credential entry requires an interactive terminal.") }
        // getpass reads from the terminal with echo disabled; arguments and history stay secret-free.
        guard let tokenBuffer = getpass("Sonos access token (hidden): ") else { throw StatusError("Credential entry cancelled.") }
        let token = String(cString: tokenBuffer)
        guard let keyBuffer = getpass("Sonos integration API key (hidden): ") else { throw StatusError("Credential entry cancelled.") }
        let key = String(cString: keyBuffer)
        let credentials = try CloudCredentials(token: token, apiKey: key)
        try save(credentials.token, account: "access-token")
        try save(credentials.apiKey, account: "api-key")
    }
}
