import Foundation
import Security

public final class KeychainStore: Sendable {
    public static let shared = KeychainStore()

    private init() {}

    public func readPassword(service: String, account: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let password = String(data: data, encoding: .utf8) else {
                throw KeychainStoreError.invalidData
            }
            return password
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.readFailed(status: status)
        }
    }

    public func savePassword(_ password: String, service: String, account: String) throws {
        let data = Data(password.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainStoreError.updateFailed(status: updateStatus)
            }
        default:
            throw KeychainStoreError.saveFailed(status: status)
        }
    }

    public func deletePassword(service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainStoreError.deleteFailed(status: status)
        }
    }
}

public enum KeychainStoreError: Error, LocalizedError {
    case invalidData
    case readFailed(status: OSStatus)
    case saveFailed(status: OSStatus)
    case updateFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Keychain data was invalid"
        case .readFailed(let status):
            return "Failed to read from Keychain (status: \(status))"
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .updateFailed(let status):
            return "Failed to update Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        }
    }
}
