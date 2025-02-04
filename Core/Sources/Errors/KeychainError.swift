import Foundation

/// Errors that can occur during keychain operations
public enum KeychainError: LocalizedError {
    case saveFailed(String)
    case retrievalFailed(String)
    case deletionFailed(String)
    case sandboxViolation(String)
    case invalidData(String)
    case duplicateItem(String)
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save to keychain: \(message)"
        case .retrievalFailed(let message):
            return "Failed to retrieve from keychain: \(message)"
        case .deletionFailed(let message):
            return "Failed to delete from keychain: \(message)"
        case .sandboxViolation(let message):
            return "Sandbox violation: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .duplicateItem(let message):
            return "Duplicate item: \(message)"
        }
    }
}
