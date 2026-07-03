import Foundation
import KubeSwitcherCore

@main
struct KubeSwitcherCoreChecks {
    static func main() async throws {
        try await addingEnvironmentUsesDefaultGroupWhenEmpty()
        try await editingEnvironmentPreservesFieldsAndUpdatesSecret()
        try await invalidKubeconfigIsRejected()
        try await deletingEnvironmentRemovesMetadataAndSecret()
        try await clearingPersistenceRemovesMetadataAndSecrets()
        try await activationBacksUpAndWritesSelectedKubeconfig()
        try await activationSetsNamespaceBeforeWritingDefaultConfig()
        try await namespacePreviewDoesNotApplyKubeconfig()
        try await activationRejectsSymlinkDefaultKubeconfig()
        try await activationDoesNotRefreshNamespaces()
        try await repeatedActivationCreatesUniqueBackups()
        try strictSummaryParsingRejectsMissingCurrentContext()
        try strictSummaryParsingRejectsMissingClusterReference()
        try kubectlLocatorFindsHomebrewWhenGuiPathIsMinimal()
        print("KubeSwitcherCoreChecks passed")
    }

    private static func addingEnvironmentUsesDefaultGroupWhenEmpty() async throws {
        let harness = try TestHarness()
        let summary = KubeConfigSummary(
            apiServer: "https://127.0.0.1:6443",
            clusterName: "sample-cluster",
            contextName: "sample-context",
            userName: "sample-user",
            sourceType: .pastedText
        )
        harness.kubectl.validationResult = .success(summary)

        let record = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(
                id: nil,
                name: "minikube-local",
                group: "",
                kind: .test,
                description: "Local development",
                kubeConfig: SampleConfigs.minikube,
                sourceType: .pastedText
            )
        )

        try check(record.group == EnvironmentStore.defaultGroup, "empty group should become default group")
        try check(record.kind == .test, "kind should be saved")
        try check(record.summary.apiServer == "https://127.0.0.1:6443", "summary should be saved")
        try check(try harness.secretStore.readConfig(id: record.id) == SampleConfigs.minikube, "secret should be saved")
    }

    private static func editingEnvironmentPreservesFieldsAndUpdatesSecret() async throws {
        let harness = try TestHarness()
        harness.kubectl.validationResult = .success(
            KubeConfigSummary(apiServer: "https://old.example:6443", clusterName: "old", contextName: "old", userName: "old", sourceType: .pastedText)
        )
        let original = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(id: nil, name: "apecloud-test", group: "apecloud", kind: .test, description: "old", kubeConfig: SampleConfigs.minikube, sourceType: .pastedText)
        )
        harness.kubectl.validationResult = .success(
            KubeConfigSummary(apiServer: "https://prod.example:6443", clusterName: "prod", contextName: "prod", userName: "admin", sourceType: .importedFile)
        )

        let updated = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(id: original.id, name: "apecloud-prod", group: "apecloud", kind: .prod, description: "production", kubeConfig: SampleConfigs.production, sourceType: .importedFile)
        )

        try check(updated.id == original.id, "edit should preserve id")
        try check(updated.name == "apecloud-prod", "edit should update name")
        try check(updated.kind == .prod, "edit should update kind")
        try check(updated.description == "production", "edit should update description")
        try check(updated.summary.userName == "admin", "edit should update summary")
        try check(try harness.secretStore.readConfig(id: original.id) == SampleConfigs.production, "edit should update secret")
    }

    private static func invalidKubeconfigIsRejected() async throws {
        let harness = try TestHarness()
        harness.kubectl.validationResult = .failure(KubeSwitcherError.invalidKubeConfig("missing clusters"))

        do {
            _ = try await harness.store.saveEnvironment(
                draft: EnvironmentDraft(id: nil, name: "bad", group: "", kind: .test, description: "", kubeConfig: "not-yaml", sourceType: .pastedText)
            )
            throw CheckFailure("invalid kubeconfig should throw")
        } catch KubeSwitcherError.invalidKubeConfig("missing clusters") {
            try check(try harness.store.loadEnvironments().isEmpty, "invalid kubeconfig should not save metadata")
        }
    }

    private static func deletingEnvironmentRemovesMetadataAndSecret() async throws {
        let harness = try TestHarness()
        harness.kubectl.validationResult = .success(
            KubeConfigSummary(apiServer: "https://127.0.0.1:6443", clusterName: "sample", contextName: "sample", userName: "sample", sourceType: .pastedText)
        )
        let record = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(id: nil, name: "minikube", group: "", kind: .test, description: "", kubeConfig: SampleConfigs.minikube, sourceType: .pastedText)
        )

        try harness.store.deleteEnvironment(id: record.id)

        try check(try harness.store.loadEnvironments().isEmpty, "delete should remove metadata")
        try check(try harness.secretStore.readConfig(id: record.id) == nil, "delete should remove secret")
    }

    private static func clearingPersistenceRemovesMetadataAndSecrets() async throws {
        let harness = try TestHarness()
        harness.kubectl.validationResult = .success(
            KubeConfigSummary(apiServer: "https://127.0.0.1:6443", clusterName: "sample", contextName: "sample", userName: "sample", sourceType: .pastedText)
        )
        let record = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(id: nil, name: "minikube", group: "", kind: .test, description: "", kubeConfig: SampleConfigs.minikube, sourceType: .pastedText)
        )

        try harness.store.clearPersistence(deleteDirectory: true)

        try check(!FileManager.default.fileExists(atPath: harness.root.path), "clear should remove persistence directory")
        try check(try harness.secretStore.readConfig(id: record.id) == nil, "clear should remove secret")
    }

    private static func activationBacksUpAndWritesSelectedKubeconfig() async throws {
        let harness = try TestHarness()
        harness.kubectl.validationResult = .success(
            KubeConfigSummary(apiServer: "https://127.0.0.1:6443", clusterName: "sample", contextName: "sample", userName: "sample", sourceType: .pastedText)
        )
        let record = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(id: nil, name: "minikube", group: "", kind: .test, description: "", kubeConfig: SampleConfigs.minikube, sourceType: .pastedText)
        )
        try "previous-config".write(to: harness.kubeConfigPath, atomically: true, encoding: .utf8)

        _ = try await harness.activator.activate(record.id, namespace: nil)

        let written = try String(contentsOf: harness.kubeConfigPath, encoding: .utf8)
        try check(written == SampleConfigs.minikube, "activation should write selected config")
        try check(harness.kubectl.listedNamespacesForPath == nil, "activation should not refresh namespaces inline")
        let settings = try harness.store.loadSettings()
        try check(settings.activeEnvironmentID == record.id, "activation should update active environment")
        try check(settings.activeNamespace == nil, "activation without namespace should not persist active namespace")
        try check(try harness.backupFiles().count == 1, "activation should backup existing config")
    }

    private static func activationSetsNamespaceBeforeWritingDefaultConfig() async throws {
        let harness = try TestHarness()
        harness.kubectl.validationResult = .success(
            KubeConfigSummary(apiServer: "https://127.0.0.1:6443", clusterName: "sample", contextName: "sample", userName: "sample", sourceType: .pastedText)
        )
        let record = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(id: nil, name: "minikube", group: "", kind: .test, description: "", kubeConfig: SampleConfigs.minikube, sourceType: .pastedText)
        )
        try harness.store.updateNamespace(environmentID: record.id, namespace: "staging")
        try check(try harness.store.loadSettings().activeNamespace == nil, "namespace selection should not update active namespace")
        harness.kubectl.namespaceMutationResult = SampleConfigs.minikube + "\n# namespace: production\n"

        _ = try await harness.activator.activate(record.id, namespace: "production")

        let written = try String(contentsOf: harness.kubeConfigPath, encoding: .utf8)
        try check(written.contains("# namespace: production"), "activation should write namespace-mutated config")
        try check(try harness.store.loadEnvironments().first?.currentNamespace == "production", "activation should persist namespace")
        try check(try harness.store.loadSettings().activeNamespace == "production", "activation should persist active namespace")
    }

    private static func namespacePreviewDoesNotApplyKubeconfig() async throws {
        let harness = try TestHarness()
        harness.kubectl.validationResult = .success(
            KubeConfigSummary(apiServer: "https://127.0.0.1:6443", clusterName: "sample", contextName: "sample", userName: "sample", sourceType: .pastedText)
        )
        let record = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(id: nil, name: "minikube", group: "", kind: .test, description: "", kubeConfig: SampleConfigs.minikube, sourceType: .pastedText)
        )
        try "previous-config".write(to: harness.kubeConfigPath, atomically: true, encoding: .utf8)

        let result = try await harness.activator.previewNamespaces(environmentID: record.id)

        try check(result.namespaces.map(\.name) == ["default", "production"], "preview should return namespaces")
        try check(harness.kubectl.listedNamespacesForConfig == SampleConfigs.minikube, "preview should list namespaces from stored config")
        try check(harness.kubectl.listedNamespacesForPath == nil, "preview should not use default kubeconfig path")
        try check(try String(contentsOf: harness.kubeConfigPath, encoding: .utf8) == "previous-config", "preview should not write default kubeconfig")
        try check(try harness.backupFiles().isEmpty, "preview should not create backups")
        let settings = try harness.store.loadSettings()
        try check(settings.activeEnvironmentID == nil, "preview should not update active environment")
        try check(settings.activeNamespace == nil, "preview should not update active namespace")
    }

    private static func activationRejectsSymlinkDefaultKubeconfig() async throws {
        let harness = try TestHarness()
        harness.kubectl.validationResult = .success(
            KubeConfigSummary(apiServer: "https://127.0.0.1:6443", clusterName: "sample", contextName: "sample", userName: "sample", sourceType: .pastedText)
        )
        let record = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(id: nil, name: "minikube", group: "", kind: .test, description: "", kubeConfig: SampleConfigs.minikube, sourceType: .pastedText)
        )
        let realTarget = harness.root.appendingPathComponent("real-config")
        try "previous-config".write(to: realTarget, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(at: harness.kubeConfigPath)
        try FileManager.default.createSymbolicLink(at: harness.kubeConfigPath, withDestinationURL: realTarget)

        do {
            _ = try await harness.activator.activate(record.id, namespace: nil)
            throw CheckFailure("activation should reject symlink kubeconfig")
        } catch KubeSwitcherError.unsafeKubeConfigTarget {
            let real = try String(contentsOf: realTarget, encoding: .utf8)
            try check(real == "previous-config", "symlink target should not be modified")
        }
    }

    private static func activationDoesNotRefreshNamespaces() async throws {
        let harness = try TestHarness()
        harness.kubectl.validationResult = .success(
            KubeConfigSummary(apiServer: "https://127.0.0.1:6443", clusterName: "sample", contextName: "sample", userName: "sample", sourceType: .pastedText)
        )
        harness.kubectl.namespaceListError = KubeSwitcherError.commandFailed("forbidden")
        let record = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(id: nil, name: "minikube", group: "", kind: .test, description: "", kubeConfig: SampleConfigs.minikube, sourceType: .pastedText)
        )

        let result = try await harness.activator.activate(record.id, namespace: nil)

        try check(result.namespaces.isEmpty, "activation should not return namespaces")
        try check(result.namespaceRefreshError == nil, "activation should not report namespace refresh warnings")
        try check(harness.kubectl.listedNamespacesForPath == nil, "activation should not call namespace list")
        try check(try harness.store.loadSettings().activeEnvironmentID == record.id, "activation should still persist active environment")
        try check(try String(contentsOf: harness.kubeConfigPath, encoding: .utf8) == SampleConfigs.minikube, "activation should still write config")
    }

    private static func repeatedActivationCreatesUniqueBackups() async throws {
        let harness = try TestHarness()
        harness.kubectl.validationResult = .success(
            KubeConfigSummary(apiServer: "https://127.0.0.1:6443", clusterName: "sample", contextName: "sample", userName: "sample", sourceType: .pastedText)
        )
        let record = try await harness.store.saveEnvironment(
            draft: EnvironmentDraft(id: nil, name: "minikube", group: "", kind: .test, description: "", kubeConfig: SampleConfigs.minikube, sourceType: .pastedText)
        )
        try "previous-config".write(to: harness.kubeConfigPath, atomically: true, encoding: .utf8)

        _ = try await harness.activator.activate(record.id, namespace: nil)
        _ = try await harness.activator.activate(record.id, namespace: nil)

        try check(try harness.backupFiles().count == 2, "repeated activations should create unique backups")
    }

    private static func strictSummaryParsingRejectsMissingCurrentContext() throws {
        let data = Data("""
        {
          "clusters": [{"name": "prod", "cluster": {"server": "https://prod.example:6443"}}],
          "contexts": [{"name": "other", "context": {"cluster": "prod", "user": "admin"}}],
          "current-context": "missing"
        }
        """.utf8)

        do {
            _ = try KubeConfigSummaryParser.summary(from: data, sourceType: .pastedText)
            throw CheckFailure("missing current-context should be rejected")
        } catch KubeSwitcherError.invalidKubeConfig("current-context does not match any context") {
        }
    }

    private static func strictSummaryParsingRejectsMissingClusterReference() throws {
        let data = Data("""
        {
          "clusters": [{"name": "prod", "cluster": {"server": "https://prod.example:6443"}}],
          "contexts": [{"name": "ctx", "context": {"cluster": "missing", "user": "admin"}}],
          "current-context": "ctx"
        }
        """.utf8)

        do {
            _ = try KubeConfigSummaryParser.summary(from: data, sourceType: .pastedText)
            throw CheckFailure("missing referenced cluster should be rejected")
        } catch KubeSwitcherError.invalidKubeConfig("context references missing cluster") {
        }
    }

    private static func kubectlLocatorFindsHomebrewWhenGuiPathIsMinimal() throws {
        let locator = KubectlExecutableLocator(
            fileExists: { $0 == "/opt/homebrew/bin/kubectl" },
            isExecutable: { $0 == "/opt/homebrew/bin/kubectl" }
        )
        let url = try locator.locate(environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"])
        try check(url.path == "/opt/homebrew/bin/kubectl", "GUI PATH should still locate Homebrew kubectl")
    }

    private static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() {
            throw CheckFailure(message)
        }
    }
}

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private final class TestHarness {
    let root: URL
    let metadataURL: URL
    let kubeConfigPath: URL
    let secretStore = InMemorySecretStore()
    let kubectl = FakeKubectlClient()
    let store: EnvironmentStore
    let activator: EnvironmentActivator

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KubeSwitcherChecks-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        metadataURL = root.appendingPathComponent("environments.json")
        kubeConfigPath = root.appendingPathComponent("config")
        store = EnvironmentStore(metadataURL: metadataURL, secretStore: secretStore, kubectl: kubectl)
        activator = EnvironmentActivator(store: store, kubectl: kubectl, kubeConfigPath: kubeConfigPath)
    }

    func backupFiles() throws -> [URL] {
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        return files.filter { $0.lastPathComponent.hasPrefix("config.kubeswitcher-backup-") }
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

private final class FakeKubectlClient: KubectlClientProtocol {
    var validationResult: Result<KubeConfigSummary, Error> = .failure(KubeSwitcherError.kubectlUnavailable)
    var namespaceMutationResult: String?
    var namespaceListError: Error?
    var listedNamespacesForConfig: String?
    var listedNamespacesForPath: URL?

    func validate(kubeConfig: String, sourceType: KubeConfigSourceType) async throws -> KubeConfigSummary {
        switch validationResult {
        case .success(var summary):
            summary.sourceType = sourceType
            return summary
        case .failure(let error):
            throw error
        }
    }

    func kubeConfig(_ kubeConfig: String, settingNamespace namespace: String) async throws -> String {
        namespaceMutationResult ?? kubeConfig
    }

    func listNamespaces(kubeConfig: String) async throws -> [KubeNamespace] {
        if let namespaceListError {
            throw namespaceListError
        }
        listedNamespacesForConfig = kubeConfig
        return [
            KubeNamespace(name: "default", status: "Active"),
            KubeNamespace(name: "production", status: "Active")
        ]
    }

    func listNamespaces(kubeConfigPath: URL) async throws -> [KubeNamespace] {
        if let namespaceListError {
            throw namespaceListError
        }
        listedNamespacesForPath = kubeConfigPath
        return [
            KubeNamespace(name: "default", status: "Active"),
            KubeNamespace(name: "production", status: "Active")
        ]
    }
}

private enum SampleConfigs {
    static let minikube = """
    apiVersion: v1
    clusters:
    - cluster:
        server: https://127.0.0.1:6443
      name: sample-cluster
    contexts:
    - context:
        cluster: sample-cluster
        user: sample-user
      name: sample-context
    current-context: sample-context
    users:
    - name: sample-user
    """

    static let production = """
    apiVersion: v1
    clusters:
    - cluster:
        server: https://prod.example:6443
      name: prod
    contexts:
    - context:
        cluster: prod
        user: admin
      name: prod
    current-context: prod
    users:
    - name: admin
    """
}
