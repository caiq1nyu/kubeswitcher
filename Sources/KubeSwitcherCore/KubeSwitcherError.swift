import Foundation

public enum KubeSwitcherError: Error, Equatable, LocalizedError, Sendable {
    case invalidKubeConfig(String)
    case kubectlUnavailable
    case commandFailed(String)
    case environmentNotFound
    case missingKubeConfigSecret
    case unsafeKubeConfigTarget
    case keychainFailure(String)
    case persistenceFailure(String)

    public var errorDescription: String? {
        switch self {
        case .invalidKubeConfig(let message):
            return "Invalid kubeconfig: \(message)"
        case .kubectlUnavailable:
            return "kubectl was not found. Checked PATH, /opt/homebrew/bin/kubectl, and /usr/local/bin/kubectl"
        case .commandFailed(let message):
            return message
        case .environmentNotFound:
            return "Environment was not found"
        case .missingKubeConfigSecret:
            return "Kubeconfig content is missing"
        case .unsafeKubeConfigTarget:
            return "Default kubeconfig target is a symbolic link; refusing to overwrite it"
        case .keychainFailure(let message):
            return "Keychain error: \(message)"
        case .persistenceFailure(let message):
            return "Persistence error: \(message)"
        }
    }
}
