import Foundation

public final class EnvironmentStore: @unchecked Sendable {
    public static let defaultGroup = "默认分组"

    private let metadataURL: URL
    private let secretStore: KubeConfigSecretStore
    private let kubectl: KubectlClientProtocol
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public var persistenceDirectoryURL: URL {
        metadataURL.deletingLastPathComponent()
    }

    public convenience init(kubectl: KubectlClientProtocol = KubectlClient()) throws {
        let support = try Self.defaultApplicationSupportURL()
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.init(
            metadataURL: support.appendingPathComponent("environments.json"),
            secretStore: KeychainKubeConfigStore(),
            kubectl: kubectl
        )
    }

    public init(
        metadataURL: URL,
        secretStore: KubeConfigSecretStore,
        kubectl: KubectlClientProtocol,
        fileManager: FileManager = .default
    ) {
        self.metadataURL = metadataURL
        self.secretStore = secretStore
        self.kubectl = kubectl
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func loadEnvironments() throws -> [EnvironmentRecord] {
        let snapshot = try loadSnapshot()
        return snapshot.environments
    }

    public func loadSettings() throws -> KubeSwitcherSettings {
        try loadSnapshot().settings
    }

    public func saveSettings(_ settings: KubeSwitcherSettings) throws {
        var snapshot = try loadSnapshot()
        snapshot.settings = settings
        try saveSnapshot(snapshot)
    }

    @discardableResult
    public func saveEnvironment(draft: EnvironmentDraft) async throws -> EnvironmentRecord {
        try await saveEnvironment(draft: draft, initialNamespace: nil)
    }

    private func saveEnvironment(draft: EnvironmentDraft, initialNamespace: String?) async throws -> EnvironmentRecord {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw KubeSwitcherError.invalidKubeConfig("environment name is required")
        }

        let summary = try await kubectl.validate(kubeConfig: draft.kubeConfig, sourceType: draft.sourceType)
        var snapshot = try loadSnapshot()
        let now = Date()
        let normalizedGroup = Self.normalizedGroup(draft.group)

        let record: EnvironmentRecord
        if let id = draft.id, let index = snapshot.environments.firstIndex(where: { $0.id == id }) {
            let old = snapshot.environments[index]
            record = EnvironmentRecord(
                id: old.id,
                name: trimmedName,
                group: normalizedGroup,
                kind: draft.kind,
                description: draft.description,
                currentNamespace: old.currentNamespace,
                summary: summary,
                createdAt: old.createdAt,
                updatedAt: now
            )
            snapshot.environments[index] = record
        } else {
            record = EnvironmentRecord(
                id: draft.id ?? UUID(),
                name: trimmedName,
                group: normalizedGroup,
                kind: draft.kind,
                description: draft.description,
                currentNamespace: initialNamespace,
                summary: summary,
                createdAt: now,
                updatedAt: now
            )
            snapshot.environments.append(record)
        }

        let previousConfig = try? secretStore.readConfig(id: record.id)
        try secretStore.saveConfig(draft.kubeConfig, id: record.id)
        snapshot.environments.sort { lhs, rhs in
            if lhs.group == rhs.group { return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }
            return lhs.group.localizedCaseInsensitiveCompare(rhs.group) == .orderedAscending
        }
        do {
            try saveSnapshot(snapshot)
        } catch {
            if let previousConfig {
                try? secretStore.saveConfig(previousConfig, id: record.id)
            } else {
                try? secretStore.deleteConfig(id: record.id)
            }
            throw error
        }
        return record
    }

    public func exportEnvironments(ids: Set<UUID>) throws -> Data {
        let records = try loadEnvironments().filter { ids.contains($0.id) }
        let entries = try records.map { record in
            EnvironmentArchive.Entry(
                name: record.name, group: record.group, kind: record.kind,
                description: record.description, currentNamespace: record.currentNamespace,
                kubeConfig: try kubeConfig(id: record.id)
            )
        }
        return try encoder.encode(EnvironmentArchive(environments: entries))
    }

    public func importEnvironments(data: Data) async throws -> EnvironmentImportResult {
        let archive = try decoder.decode(EnvironmentArchive.self, from: data)
        guard archive.format == "kubeswitcher", archive.version == 1 else {
            throw KubeSwitcherError.persistenceFailure("Unsupported KubeSwitcher export format or version")
        }
        var result = EnvironmentImportResult()
        for entry in archive.environments {
            do {
                let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let group = Self.normalizedGroup(entry.group)
                let existing = try loadEnvironments()
                if existing.contains(where: { $0.group == group && $0.name == name }) {
                    result.failed += 1
                    continue
                }
                // Validate locally, then persist metadata and secret together using the normal save path.
                _ = try await saveEnvironment(draft: EnvironmentDraft(
                    id: nil, name: name, group: group, kind: entry.kind,
                    description: entry.description, kubeConfig: entry.kubeConfig,
                    sourceType: .importedFile
                ), initialNamespace: entry.currentNamespace)
                result.succeeded += 1
            } catch {
                result.failed += 1
            }
        }
        return result
    }

    public func deleteEnvironment(id: UUID) throws {
        var snapshot = try loadSnapshot()
        let beforeCount = snapshot.environments.count
        snapshot.environments.removeAll { $0.id == id }
        guard snapshot.environments.count != beforeCount else {
            throw KubeSwitcherError.environmentNotFound
        }
        if snapshot.settings.activeEnvironmentID == id {
            snapshot.settings.activeEnvironmentID = nil
            snapshot.settings.activeNamespace = nil
        }
        try saveSnapshot(snapshot)
        try secretStore.deleteConfig(id: id)
    }

    public func clearPersistence(deleteDirectory: Bool) throws {
        let snapshot = try loadSnapshot()
        for environment in snapshot.environments {
            try secretStore.deleteConfig(id: environment.id)
        }

        if deleteDirectory {
            if fileManager.fileExists(atPath: persistenceDirectoryURL.path) {
                try fileManager.removeItem(at: persistenceDirectoryURL)
            }
        } else {
            try saveSnapshot(EnvironmentSnapshot(environments: [], settings: KubeSwitcherSettings()))
        }
    }

    public func kubeConfig(id: UUID) throws -> String {
        guard let config = try secretStore.readConfig(id: id) else {
            throw KubeSwitcherError.missingKubeConfigSecret
        }
        return config
    }

    public func updateNamespace(environmentID: UUID, namespace: String?) throws {
        var snapshot = try loadSnapshot()
        guard let index = snapshot.environments.firstIndex(where: { $0.id == environmentID }) else {
            throw KubeSwitcherError.environmentNotFound
        }
        snapshot.environments[index].currentNamespace = namespace
        snapshot.environments[index].updatedAt = Date()
        try saveSnapshot(snapshot)
    }

    public static func normalizedGroup(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultGroup : trimmed
    }

    private func loadSnapshot() throws -> EnvironmentSnapshot {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return EnvironmentSnapshot(environments: [], settings: KubeSwitcherSettings())
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            return try decoder.decode(EnvironmentSnapshot.self, from: data)
        } catch {
            throw KubeSwitcherError.persistenceFailure(error.localizedDescription)
        }
    }

    private func saveSnapshot(_ snapshot: EnvironmentSnapshot) throws {
        do {
            let directory = metadataURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: metadataURL, options: [.atomic])
        } catch {
            throw KubeSwitcherError.persistenceFailure(error.localizedDescription)
        }
    }

    public static func defaultApplicationSupportURL() throws -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let base = urls.first else {
            throw KubeSwitcherError.persistenceFailure("Application Support directory is unavailable")
        }
        let current = base.appendingPathComponent("KubeSwitcher", isDirectory: true)
        let legacy = base.appendingPathComponent("KubeDeck", isDirectory: true)
        let fileManager = FileManager.default
        let currentMetadata = current.appendingPathComponent("environments.json")
        let legacyMetadata = legacy.appendingPathComponent("environments.json")
        if !fileManager.fileExists(atPath: currentMetadata.path),
           fileManager.fileExists(atPath: legacyMetadata.path) {
            return legacy
        }
        return current
    }
}

private struct EnvironmentSnapshot: Codable {
    var environments: [EnvironmentRecord]
    var settings: KubeSwitcherSettings
}
