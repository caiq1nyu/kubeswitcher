import Foundation

public final class EnvironmentActivator: @unchecked Sendable {
    private let store: EnvironmentStore
    private let kubectl: KubectlClientProtocol
    private let kubeConfigPath: URL
    private let fileManager: FileManager

    public init(
        store: EnvironmentStore,
        kubectl: KubectlClientProtocol,
        kubeConfigPath: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kube", isDirectory: true)
            .appendingPathComponent("config"),
        fileManager: FileManager = .default
    ) {
        self.store = store
        self.kubectl = kubectl
        self.kubeConfigPath = kubeConfigPath
        self.fileManager = fileManager
    }

    @discardableResult
    public func activate(_ environmentID: UUID, namespace: String?) async throws -> ActivationResult {
        let environments = try store.loadEnvironments()
        guard environments.contains(where: { $0.id == environmentID }) else {
            throw KubeSwitcherError.environmentNotFound
        }

        var config = try store.kubeConfig(id: environmentID)
        let normalizedNamespace = namespace?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedNamespace, !normalizedNamespace.isEmpty {
            config = try await kubectl.kubeConfig(config, settingNamespace: normalizedNamespace)
        }

        try writeDefaultKubeConfig(config)
        if let normalizedNamespace, !normalizedNamespace.isEmpty {
            try store.updateNamespace(environmentID: environmentID, namespace: normalizedNamespace)
        }
        var settings = try store.loadSettings()
        settings.activeEnvironmentID = environmentID
        settings.activeNamespace = normalizedNamespace?.isEmpty == false ? normalizedNamespace : nil
        try store.saveSettings(settings)

        return ActivationResult(namespaces: [])
    }

    private func writeDefaultKubeConfig(_ config: String) throws {
        let directory = kubeConfigPath.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: kubeConfigPath.path) {
            if isSymbolicLink(kubeConfigPath) {
                throw KubeSwitcherError.unsafeKubeConfigTarget
            }
            let backup = directory.appendingPathComponent("config.kubeswitcher-backup-\(Self.timestamp())")
            try fileManager.copyItem(at: kubeConfigPath, to: backup)
        }

        let data = Data(config.utf8)
        try data.write(to: kubeConfigPath, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: kubeConfigPath.path)
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return "\(formatter.string(from: Date()))-\(UUID().uuidString.prefix(8))"
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    public func previewNamespaces(environmentID: UUID) async throws -> ActivationResult {
        let environments = try store.loadEnvironments()
        guard environments.contains(where: { $0.id == environmentID }) else {
            throw KubeSwitcherError.environmentNotFound
        }
        let config = try store.kubeConfig(id: environmentID)
        do {
            let namespaces = try await kubectl.listNamespaces(kubeConfig: config)
            return ActivationResult(namespaces: namespaces)
        } catch {
            return ActivationResult(namespaces: [], namespaceRefreshError: error.localizedDescription)
        }
    }
}
