import Foundation

// MARK: - ResticCommand

/// Commands supported by the Restic service
enum ResticCommand: String {
    case `init`
    case backup
    case restore
    case list
}

// MARK: - ResticCommandError

/// Errors that can occur during Restic command execution
public enum ResticCommandError: LocalizedError {
    case resticNotInstalled
    case repositoryNotFound
    case repositoryExists
    case invalidRepository(String)
    case invalidSettings(String)
    case invalidCredentials(String)
    case insufficientPermissions
    case operationNotFound
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .resticNotInstalled:
            "Restic is not installed"
        case .repositoryNotFound:
            "Repository not found"
        case .repositoryExists:
            "Repository already exists"
        case let .invalidRepository(message):
            "Invalid repository: \(message)"
        case let .invalidSettings(message):
            "Invalid settings: \(message)"
        case let .invalidCredentials(message):
            "Invalid credentials: \(message)"
        case .insufficientPermissions:
            "Insufficient permissions"
        case .operationNotFound:
            "Operation not found"
        case let .operationFailed(message):
            "Operation failed: \(message)"
        }
    }
}
