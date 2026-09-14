import Foundation
import Security

nonisolated struct ConnectorCredentials: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    var completionWriteAccess: Bool? = nil

    func needsRefresh(at date: Date) -> Bool {
        expiresAt.map { $0.timeIntervalSince(date) < 60 } ?? false
    }
}

@MainActor
protocol ConnectorCredentialStorage {
    func read(for provider: ConnectorProviderID) throws -> ConnectorCredentials?
    func save(_ credentials: ConnectorCredentials, for provider: ConnectorProviderID) throws
    func remove(for provider: ConnectorProviderID) throws
}

@MainActor
final class ConnectorKeychain: ConnectorCredentialStorage {
    private let service = "com.shigorefu.thruflow.connectors.v1"

    func read(for provider: ConnectorProviderID) throws -> ConnectorCredentials? {
        var query = query(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw ConnectorStoreError.keychain
        }
        do { return try JSONDecoder().decode(ConnectorCredentials.self, from: data) }
        catch { throw ConnectorStoreError.keychain }
    }

    func save(_ credentials: ConnectorCredentials, for provider: ConnectorProviderID) throws {
        let data = try JSONEncoder().encode(credentials)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let query = query(for: provider)
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw ConnectorStoreError.keychain
            }
        } else if status != errSecSuccess {
            throw ConnectorStoreError.keychain
        }
    }

    func remove(for provider: ConnectorProviderID) throws {
        let status = SecItemDelete(query(for: provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ConnectorStoreError.keychain
        }
    }

    private func query(for provider: ConnectorProviderID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: provider.rawValue,
         kSecAttrSynchronizable as String: false]
    }
}

@MainActor
final class InMemoryConnectorCredentials: ConnectorCredentialStorage {
    private var values: [ConnectorProviderID: ConnectorCredentials] = [:]
    func read(for provider: ConnectorProviderID) throws -> ConnectorCredentials? { values[provider] }
    func save(_ credentials: ConnectorCredentials, for provider: ConnectorProviderID) throws {
        values[provider] = credentials
    }
    func remove(for provider: ConnectorProviderID) throws { values.removeValue(forKey: provider) }
}
