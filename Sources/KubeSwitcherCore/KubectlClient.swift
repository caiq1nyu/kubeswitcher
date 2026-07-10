import Foundation

public protocol KubectlClientProtocol: AnyObject {
    func validate(kubeConfig: String, sourceType: KubeConfigSourceType) async throws -> KubeConfigSummary
    func kubeConfig(_ kubeConfig: String, settingNamespace namespace: String) async throws -> String
    func listNamespaces(kubeConfig: String) async throws -> [KubeNamespace]
    func listNamespaces(kubeConfigPath: URL) async throws -> [KubeNamespace]
    func currentNamespace(kubeConfigPath: URL) async throws -> String?
}

public final class KubectlClient: KubectlClientProtocol, @unchecked Sendable {
    private let fileManager: FileManager
    private let locator: KubectlExecutableLocator

    public init(fileManager: FileManager = .default, locator: KubectlExecutableLocator = KubectlExecutableLocator()) {
        self.fileManager = fileManager
        self.locator = locator
    }

    public func validate(kubeConfig: String, sourceType: KubeConfigSourceType) async throws -> KubeConfigSummary {
        let path = try writeTemporaryConfig(kubeConfig)
        defer { try? fileManager.removeItem(at: path.deletingLastPathComponent()) }

        let output = try await runKubectl(["--kubeconfig", path.path, "config", "view", "--raw", "-o", "json"])
        let data = Data(output.utf8)
        return try KubeConfigSummaryParser.summary(from: data, sourceType: sourceType)
    }

    public func kubeConfig(_ kubeConfig: String, settingNamespace namespace: String) async throws -> String {
        let path = try writeTemporaryConfig(kubeConfig)
        defer { try? fileManager.removeItem(at: path.deletingLastPathComponent()) }

        _ = try await runKubectl(["--kubeconfig", path.path, "config", "set-context", "--current", "--namespace", namespace])
        return try String(contentsOf: path, encoding: .utf8)
    }

    public func listNamespaces(kubeConfigPath: URL) async throws -> [KubeNamespace] {
        let output = try await runKubectl(["--kubeconfig", kubeConfigPath.path, "get", "namespaces", "-o", "json"])
        let data = Data(output.utf8)
        let list = try JSONDecoder().decode(NamespaceList.self, from: data)
        return list.items.map {
            KubeNamespace(
                name: $0.metadata.name,
                status: $0.status.phase,
                createdAt: Self.parseKubernetesTimestamp($0.metadata.creationTimestamp)
            )
        }
    }

    public func listNamespaces(kubeConfig: String) async throws -> [KubeNamespace] {
        let path = try writeTemporaryConfig(kubeConfig)
        defer { try? fileManager.removeItem(at: path.deletingLastPathComponent()) }
        return try await listNamespaces(kubeConfigPath: path)
    }

    public func currentNamespace(kubeConfigPath: URL) async throws -> String? {
        let output = try await runKubectl(["--kubeconfig", kubeConfigPath.path, "config", "view", "--minify", "-o", "json"])
        let data = Data(output.utf8)
        return try KubeConfigSummaryParser.currentNamespace(from: data)
    }

    private func writeTemporaryConfig(_ kubeConfig: String) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("KubeSwitcher-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("config")
        try kubeConfig.write(to: path, atomically: true, encoding: .utf8)
        return path
    }

    private func runKubectl(_ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            do {
                process.executableURL = try locator.locate()
            } catch {
                continuation.resume(throwing: error)
                return
            }
            process.arguments = arguments
            process.currentDirectoryURL = fileManager.homeDirectoryForCurrentUser

            let directory = fileManager.temporaryDirectory
                .appendingPathComponent("KubeSwitcherCommand-\(UUID().uuidString)", isDirectory: true)
            let outputURL = directory.appendingPathComponent("stdout")
            let errorURL = directory.appendingPathComponent("stderr")
            let outputHandle: FileHandle
            let errorHandle: FileHandle
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                fileManager.createFile(atPath: outputURL.path, contents: nil)
                fileManager.createFile(atPath: errorURL.path, contents: nil)
                outputHandle = try FileHandle(forWritingTo: outputURL)
                errorHandle = try FileHandle(forWritingTo: errorURL)
            } catch {
                continuation.resume(throwing: KubeSwitcherError.persistenceFailure(error.localizedDescription))
                return
            }

            process.standardOutput = outputHandle
            process.standardError = errorHandle

            process.terminationHandler = { process in
                try? outputHandle.close()
                try? errorHandle.close()
                let outputData = (try? Data(contentsOf: outputURL)) ?? Data()
                let errorData = (try? Data(contentsOf: errorURL)) ?? Data()
                try? self.fileManager.removeItem(at: directory)
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else if process.terminationStatus == 127 {
                    continuation.resume(throwing: KubeSwitcherError.kubectlUnavailable)
                } else {
                    continuation.resume(throwing: KubeSwitcherError.commandFailed(error.isEmpty ? output : error))
                }
            }

            do {
                try process.run()
            } catch {
                try? outputHandle.close()
                try? errorHandle.close()
                try? fileManager.removeItem(at: directory)
                continuation.resume(throwing: KubeSwitcherError.kubectlUnavailable)
            }
        }
    }

    private static func parseKubernetesTimestamp(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

public struct KubectlExecutableLocator: Sendable {
    private let fileExists: @Sendable (String) -> Bool
    private let isExecutable: @Sendable (String) -> Bool

    public init(
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.fileExists = fileExists
        self.isExecutable = isExecutable
    }

    public func locate(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> URL {
        var candidates: [String] = []
        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/kubectl" })
        }
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/kubectl",
            "/usr/local/bin/kubectl",
            "/usr/bin/kubectl"
        ])

        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate).inserted {
            if fileExists(candidate), isExecutable(candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        throw KubeSwitcherError.kubectlUnavailable
    }
}

public enum KubeConfigSummaryParser {
    public static func summary(from data: Data, sourceType: KubeConfigSourceType) throws -> KubeConfigSummary {
        do {
            let view = try JSONDecoder().decode(KubeConfigView.self, from: data)
            return try view.summary(sourceType: sourceType)
        } catch let error as KubeSwitcherError {
            throw error
        } catch {
            throw KubeSwitcherError.invalidKubeConfig(error.localizedDescription)
        }
    }

    public static func currentNamespace(from data: Data) throws -> String? {
        do {
            let view = try JSONDecoder().decode(KubeConfigView.self, from: data)
            return try view.currentNamespace()
        } catch let error as KubeSwitcherError {
            throw error
        } catch {
            throw KubeSwitcherError.invalidKubeConfig(error.localizedDescription)
        }
    }
}

private struct KubeConfigView: Decodable {
    struct NamedCluster: Decodable {
        struct Cluster: Decodable {
            let server: String?
        }
        let name: String
        let cluster: Cluster
    }

    struct NamedContext: Decodable {
        struct Context: Decodable {
            let cluster: String?
            let user: String?
            let namespace: String?
        }
        let name: String
        let context: Context
    }

    let clusters: [NamedCluster]
    let contexts: [NamedContext]
    let currentContext: String?

    enum CodingKeys: String, CodingKey {
        case clusters
        case contexts
        case currentContext = "current-context"
    }

    func currentNamespace() throws -> String? {
        guard let currentContext, !currentContext.isEmpty else {
            throw KubeSwitcherError.invalidKubeConfig("missing current-context")
        }
        guard let selectedContext = contexts.first(where: { $0.name == currentContext }) else {
            throw KubeSwitcherError.invalidKubeConfig("current-context does not match any context")
        }
        let namespace = selectedContext.context.namespace?.trimmingCharacters(in: .whitespacesAndNewlines)
        return namespace?.isEmpty == false ? namespace : nil
    }

    func summary(sourceType: KubeConfigSourceType) throws -> KubeConfigSummary {
        guard let currentContext, !currentContext.isEmpty else {
            throw KubeSwitcherError.invalidKubeConfig("missing current-context")
        }
        guard let selectedContext = contexts.first(where: { $0.name == currentContext }) else {
            throw KubeSwitcherError.invalidKubeConfig("current-context does not match any context")
        }
        guard !contexts.isEmpty else {
            throw KubeSwitcherError.invalidKubeConfig("missing context")
        }
        guard let clusterName = selectedContext.context.cluster, !clusterName.isEmpty else {
            throw KubeSwitcherError.invalidKubeConfig("missing cluster reference")
        }
        guard let cluster = clusters.first(where: { $0.name == clusterName }),
              let apiServer = cluster.cluster.server,
              !apiServer.isEmpty
        else {
            throw KubeSwitcherError.invalidKubeConfig("context references missing cluster")
        }
        return KubeConfigSummary(
            apiServer: apiServer,
            clusterName: cluster.name,
            contextName: selectedContext.name,
            userName: selectedContext.context.user ?? "",
            sourceType: sourceType
        )
    }
}

private struct NamespaceList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let creationTimestamp: String?
        }
        struct Status: Decodable {
            let phase: String
        }
        let metadata: Metadata
        let status: Status
    }
    let items: [Item]
}
