import Foundation

public enum EnvironmentKind: String, Codable, CaseIterable, Sendable {
    case test
    case prod
}

public enum KubeConfigSourceType: String, Codable, Sendable {
    case pastedText
    case importedFile
}

public struct KubeConfigSummary: Codable, Equatable, Sendable {
    public var apiServer: String
    public var clusterName: String
    public var contextName: String
    public var userName: String
    public var sourceType: KubeConfigSourceType

    public init(apiServer: String, clusterName: String, contextName: String, userName: String, sourceType: KubeConfigSourceType) {
        self.apiServer = apiServer
        self.clusterName = clusterName
        self.contextName = contextName
        self.userName = userName
        self.sourceType = sourceType
    }
}

public struct EnvironmentRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var group: String
    public var kind: EnvironmentKind
    public var description: String
    public var currentNamespace: String?
    public var summary: KubeConfigSummary
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        group: String,
        kind: EnvironmentKind,
        description: String,
        currentNamespace: String?,
        summary: KubeConfigSummary,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.kind = kind
        self.description = description
        self.currentNamespace = currentNamespace
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct EnvironmentDraft: Sendable {
    public var id: UUID?
    public var name: String
    public var group: String
    public var kind: EnvironmentKind
    public var description: String
    public var kubeConfig: String
    public var sourceType: KubeConfigSourceType

    public init(
        id: UUID?,
        name: String,
        group: String,
        kind: EnvironmentKind,
        description: String,
        kubeConfig: String,
        sourceType: KubeConfigSourceType
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.kind = kind
        self.description = description
        self.kubeConfig = kubeConfig
        self.sourceType = sourceType
    }
}

public enum HotKeyModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case command
    case option
    case control
    case shift
}

public struct HotKeyPreference: Codable, Equatable, Sendable {
    public static let availableKeys = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").map(String.init)

    public var key: String
    public var modifiers: [HotKeyModifier]

    public init(key: String = "K", modifiers: [HotKeyModifier] = [.command]) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.key = Self.availableKeys.contains(normalizedKey) ? normalizedKey : "K"
        self.modifiers = modifiers.isEmpty ? [.command] : Array(Set(modifiers)).sorted { $0.sortOrder < $1.sortOrder }
    }

    public var displayText: String {
        modifiers.map(\.displayText).joined() + key
    }
}

public extension HotKeyModifier {
    var displayText: String {
        switch self {
        case .command:
            return "⌘"
        case .option:
            return "⌥"
        case .control:
            return "⌃"
        case .shift:
            return "⇧"
        }
    }

    var sortOrder: Int {
        switch self {
        case .control:
            return 0
        case .option:
            return 1
        case .shift:
            return 2
        case .command:
            return 3
        }
    }
}

public struct KubeSwitcherSettings: Codable, Equatable, Sendable {
    public var language: AppLanguage
    public var activeEnvironmentID: UUID?
    public var activeNamespace: String?
    public var hotKey: HotKeyPreference

    public init(
        language: AppLanguage = .zhHans,
        activeEnvironmentID: UUID? = nil,
        activeNamespace: String? = nil,
        hotKey: HotKeyPreference = HotKeyPreference()
    ) {
        self.language = language
        self.activeEnvironmentID = activeEnvironmentID
        self.activeNamespace = activeNamespace
        self.hotKey = hotKey
    }

    enum CodingKeys: String, CodingKey {
        case language
        case activeEnvironmentID
        case activeNamespace
        case hotKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .zhHans
        activeEnvironmentID = try container.decodeIfPresent(UUID.self, forKey: .activeEnvironmentID)
        activeNamespace = try container.decodeIfPresent(String.self, forKey: .activeNamespace)
        hotKey = try container.decodeIfPresent(HotKeyPreference.self, forKey: .hotKey) ?? HotKeyPreference()
    }
}

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case zhHans
    case english
}

public struct KubeNamespace: Identifiable, Codable, Equatable, Sendable {
    public var id: String { name }
    public var name: String
    public var status: String
    public var createdAt: Date?

    public init(name: String, status: String, createdAt: Date? = nil) {
        self.name = name
        self.status = status
        self.createdAt = createdAt
    }
}

public struct ActivationResult: Equatable, Sendable {
    public var namespaces: [KubeNamespace]
    public var namespaceRefreshError: String?

    public init(namespaces: [KubeNamespace], namespaceRefreshError: String? = nil) {
        self.namespaces = namespaces
        self.namespaceRefreshError = namespaceRefreshError
    }
}
