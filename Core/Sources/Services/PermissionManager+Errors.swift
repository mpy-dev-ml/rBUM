import Foundation

/// Errors that can occur during permission operations
public enum PermissionError: LocalizedError {
    case persistenceFailed(String)
    case recoveryFailed(String)
    case revocationFailed(String)
    case fileNotFound(URL)
    case readAccessDenied(URL)
    case writeAccessDenied(URL)
    case sandboxAccessDenied(URL)
    case fileEncrypted(URL)
    case readOnlyVolume(URL)

    public var errorDescription: String? {
        switch self {
        case let .persistenceFailed(message):
            "Failed to persist permission: \(message)"
        case let .recoveryFailed(message):
            "Failed to recover permission: \(message)"
        case let .revocationFailed(message):
            "Failed to revoke permission: \(message)"
        case let .fileNotFound(url):
            "File not found at path: \(url.path)"
        case let .readAccessDenied(url):
            "Read access denied for file: \(url.path)"
        case let .writeAccessDenied(url):
            "Write access denied for file: \(url.path)"
        case let .sandboxAccessDenied(url):
            "Sandbox access denied for file: \(url.path)"
        case let .fileEncrypted(url):
            "Cannot access encrypted file: \(url.path)"
        case let .readOnlyVolume(url):
            "File is on a read-only volume: \(url.path)"
        }
    }
}
