import Foundation
import KubeSwitcherCore

struct AppPreferences: Equatable {
    var kubeConfigPath: String
    var dataDirectoryPath: String
    var deletePersistenceDirectoryOnClear: Bool

    static func defaults() -> AppPreferences {
        AppPreferences(
            kubeConfigPath: "~/.kube/config",
            dataDirectoryPath: defaultDataDirectoryPath(),
            deletePersistenceDirectoryOnClear: true
        )
    }

    var resolvedKubeConfigURL: URL {
        URL(fileURLWithPath: kubeConfigPath.expandingTildePath)
    }

    var resolvedDataDirectoryURL: URL {
        URL(fileURLWithPath: dataDirectoryPath.expandingTildePath, isDirectory: true)
    }

    private static func defaultDataDirectoryPath() -> String {
        if let url = try? EnvironmentStore.defaultApplicationSupportURL() {
            return url.path.abbreviatingHomeDirectory
        }
        return "~/Library/Application Support/KubeSwitcher"
    }
}

enum AppPreferencesStore {
    private static let kubeConfigPathKey = "kubeConfigPath"
    private static let dataDirectoryPathKey = "dataDirectoryPath"
    private static let deletePersistenceDirectoryOnClearKey = "deletePersistenceDirectoryOnClear"

    static func load(userDefaults: UserDefaults = .standard) -> AppPreferences {
        let defaults = AppPreferences.defaults()
        return AppPreferences(
            kubeConfigPath: userDefaults.string(forKey: kubeConfigPathKey) ?? defaults.kubeConfigPath,
            dataDirectoryPath: userDefaults.string(forKey: dataDirectoryPathKey) ?? defaults.dataDirectoryPath,
            deletePersistenceDirectoryOnClear: userDefaults.object(forKey: deletePersistenceDirectoryOnClearKey) as? Bool
                ?? defaults.deletePersistenceDirectoryOnClear
        )
    }

    static func save(_ preferences: AppPreferences, userDefaults: UserDefaults = .standard) {
        userDefaults.set(preferences.kubeConfigPath, forKey: kubeConfigPathKey)
        userDefaults.set(preferences.dataDirectoryPath, forKey: dataDirectoryPathKey)
        userDefaults.set(preferences.deletePersistenceDirectoryOnClear, forKey: deletePersistenceDirectoryOnClearKey)
    }
}

private extension String {
    var expandingTildePath: String {
        (self as NSString).expandingTildeInPath
    }

    var abbreviatingHomeDirectory: String {
        let home = NSHomeDirectory()
        guard hasPrefix(home) else { return self }
        return "~" + dropFirst(home.count)
    }
}
