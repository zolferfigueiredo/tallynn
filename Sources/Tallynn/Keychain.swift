import Foundation
import Security

// The GitHub token lives only here, in the login keychain: never in UserDefaults, never in the log.
// The data protection keychain would need entitlements an app built by SwiftPM can't have.
private let item: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "com.zolfer.tallynn",
                                   kSecAttrAccount as String: "github"]

func savedToken() -> String? {
    var result: AnyObject?
    guard SecItemCopyMatching(item.merging([kSecReturnData as String: true]) { $1 } as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else { return nil }
    return String(decoding: data, as: UTF8.self)
}

func saveToken(_ token: String) -> Bool {
    let value = [kSecValueData as String: Data(token.utf8)]
    let status = SecItemUpdate(item as CFDictionary, value as CFDictionary)
    guard status == errSecItemNotFound else { return status == errSecSuccess }
    return SecItemAdd(item.merging(value) { $1 } as CFDictionary, nil) == errSecSuccess
}

func deleteToken() { SecItemDelete(item as CFDictionary) }
