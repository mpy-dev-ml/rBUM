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
        case .persistenceFailed(let message):
            return "Failed to persist permission: \(message)"
        case .recoveryFailed(let message):
            return "Failed to recover permission: \(message)"
        case .revocationFailed(let message):
            return "Failed to revoke permission: \(message)"
        case .fileNotFound(let url):
            return "File not found at path: \(url.path)"
        case .readAccessDenied(let url):
            return "Read access denied for file: \(url.path)"
        case .writeAccessDenied(let url):
            return "Write access denied for file: \(url.path)"
        case .sandboxAccessDenied(let url):
            return "Sandbox access denied for file: \(url.path)"
        case .fileEncrypted(let url):
            return "Cannot access encrypted file: \(url.path)"
        case .readOnlyVolume(let url):
            return "File is on a read-only volume: \(url.path)"
        }
    }
}
