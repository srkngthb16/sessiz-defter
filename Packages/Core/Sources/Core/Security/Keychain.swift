import Foundation
import Security

/// Hassas alan anahtarları Keychain'de, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
/// ile: cihaz kilitliyken okunamaz, yedekle başka cihaza taşınmaz.
public struct Keychain: Sendable {
    public enum Failure: Error, Equatable {
        case unexpectedStatus(OSStatus)
    }

    public let service: String

    public init(service: String = "com.sessizdefter.app") {
        self.service = service
    }

    public func set(_ data: Data, for account: String) throws {
        var query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.unexpectedStatus(status) }
    }

    public func data(for account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess: return item as? Data
        case errSecItemNotFound: return nil
        default: throw Failure.unexpectedStatus(status)
        }
    }

    public func remove(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
