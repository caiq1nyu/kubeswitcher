import Foundation

// Sharing format deliberately excludes local IDs, active environment and app preferences.
struct EnvironmentArchive: Codable {
    var format = "kubeswitcher"
    var version = 1
    var environments: [Entry]

    struct Entry: Codable {
        var name: String
        var group: String
        var kind: EnvironmentKind
        var description: String
        var currentNamespace: String?
        var kubeConfig: String
    }
}

public struct EnvironmentImportResult: Equatable, Sendable {
    public var succeeded = 0
    public var failed = 0
}
