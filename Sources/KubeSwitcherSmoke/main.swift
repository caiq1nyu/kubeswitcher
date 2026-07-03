import Foundation
import KubeSwitcherCore

@main
struct KubeSwitcherSmoke {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3 else {
            throw SmokeFailure("Usage: swift run KubeSwitcherSmoke /path/to/kubeconfig [namespace-to-apply]")
        }

        let kubeconfigURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let namespaceToApply = CommandLine.arguments.count == 3 ? CommandLine.arguments[2] : nil
        let kubeconfig = try String(contentsOf: kubeconfigURL, encoding: .utf8)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KubeSwitcherSmoke-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let kubectl = KubectlClient()
        let store = EnvironmentStore(
            metadataURL: root.appendingPathComponent("environments.json"),
            secretStore: InMemorySecretStore(),
            kubectl: kubectl
        )
        let appliedKubeconfigPath = root.appendingPathComponent("default-config")
        let activator = EnvironmentActivator(
            store: store,
            kubectl: kubectl,
            kubeConfigPath: appliedKubeconfigPath
        )

        let record = try await store.saveEnvironment(
            draft: EnvironmentDraft(
                id: nil,
                name: kubeconfigURL.deletingPathExtension().lastPathComponent,
                group: "smoke",
                kind: .test,
                description: "KubeSwitcher smoke test",
                kubeConfig: kubeconfig,
                sourceType: .importedFile
            )
        )
        let result = try await activator.previewNamespaces(environmentID: record.id)
        if let warning = result.namespaceRefreshError {
            throw SmokeFailure("Namespace refresh failed: \(warning)")
        }
        guard !result.namespaces.isEmpty else {
            throw SmokeFailure("Namespace refresh returned 0 namespaces")
        }

        let sample = result.namespaces.prefix(8).map(\.name).joined(separator: ", ")
        print("saved=\(record.name)")
        print("summary.cluster=\(record.summary.clusterName)")
        print("summary.context=\(record.summary.contextName)")
        print("namespaces.count=\(result.namespaces.count)")
        print("namespaces.sample=\(sample)")

        if let namespaceToApply {
            _ = try await activator.activate(record.id, namespace: namespaceToApply)
            print("applied.namespace=\(namespaceToApply)")
            print("applied.path=\(appliedKubeconfigPath.path)")
        }
    }
}

private final class InMemorySecretStore: KubeConfigSecretStore {
    private var configs: [UUID: String] = [:]

    func saveConfig(_ config: String, id: UUID) throws {
        configs[id] = config
    }

    func readConfig(id: UUID) throws -> String? {
        configs[id]
    }

    func deleteConfig(id: UUID) throws {
        configs.removeValue(forKey: id)
    }
}

private struct SmokeFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
