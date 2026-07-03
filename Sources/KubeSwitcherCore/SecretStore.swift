import Foundation
import Security

public protocol KubeConfigSecretStore: AnyObject {
    func saveConfig(_ config: String, id: UUID) throws
    func readConfig(id: UUID) throws -> String?
    func deleteConfig(id: UUID) throws
}

public final class KeychainKubeConfigStore: KubeConfigSecretStore, @unchecked Sendable {
    private let service = "com.kubeswitcher.kubeconfig"
    private let registryAccount = "__kubeswitcher_registry__"
    private let legacyService = "com.kubedeck.kubeconfig"
    private let legacyRegistryAccount = "__kubedeck_registry__"
    private var cachedRegistry: [UUID: String]?

    public init() {}

    public func saveConfig(_ config: String, id: UUID) throws {
        var registry = try loadRegistry()
        registry[id] = config
        try saveRegistry(registry)
    }

    public func readConfig(id: UUID) throws -> String? {
        var registry = try loadRegistry()
        if let config = registry[id] {
            return config
        }

        if let legacyConfig = try readLegacyConfig(id: id) {
            registry[id] = legacyConfig
            try saveRegistry(registry)
            try? deleteLegacyConfig(id: id)
            return legacyConfig
        }
        return nil
    }

    public func deleteConfig(id: UUID) throws {
        var registry = try loadRegistry()
        registry.removeValue(forKey: id)
        try saveRegistry(registry)
        try deleteLegacyConfig(id: id)
    }

    private func loadRegistry() throws -> [UUID: String] {
        if let cachedRegistry {
            return cachedRegistry
        }

        if let registry = try loadRegistry(service: service, account: registryAccount) {
            cachedRegistry = registry
            return registry
        }

        if let legacyRegistry = try loadRegistry(service: legacyService, account: legacyRegistryAccount), !legacyRegistry.isEmpty {
            cachedRegistry = legacyRegistry
            try saveRegistry(legacyRegistry)
            try? deleteRegistry(service: legacyService, account: legacyRegistryAccount)
            return legacyRegistry
        }

        cachedRegistry = [:]
        return [:]
    }

    private func loadRegistry(service: String, account: String) throws -> [UUID: String]? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KubeSwitcherError.keychainFailure(statusMessage(status))
        }
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        return Dictionary(uniqueKeysWithValues: decoded.compactMap { entry in
            UUID(uuidString: entry.key).map { ($0, entry.value) }
        })
    }

    private func saveRegistry(_ registry: [UUID: String]) throws {
        let raw = Dictionary(uniqueKeysWithValues: registry.map { ($0.key.uuidString, $0.value) })
        let data = try JSONEncoder().encode(raw)
        let query = baseQuery(service: service, account: registryAccount)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw KubeSwitcherError.keychainFailure(statusMessage(insertStatus))
            }
            cachedRegistry = registry
            return
        }

        guard status == errSecSuccess else {
            throw KubeSwitcherError.keychainFailure(statusMessage(status))
        }
        cachedRegistry = registry
    }

    private func readLegacyConfig(id: UUID) throws -> String? {
        var query = baseQuery(service: legacyService, account: id.uuidString)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KubeSwitcherError.keychainFailure(statusMessage(status))
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteLegacyConfig(id: UUID) throws {
        let status = SecItemDelete(baseQuery(service: legacyService, account: id.uuidString) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KubeSwitcherError.keychainFailure(statusMessage(status))
        }
    }

    private func deleteRegistry(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KubeSwitcherError.keychainFailure(statusMessage(status))
        }
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func statusMessage(_ status: OSStatus) -> String {
        SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
    }
}
