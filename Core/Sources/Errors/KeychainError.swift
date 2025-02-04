import Foundation

/// Errors that can occur during keychain operations
public enum KeychainError: LocalizedError {
    case saveFailed
    case retrievalFailed
    case deleteFailed
    case updateFailed
    case accessValidationFailed
    case xpcConfigurationFailed
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save item to keychain"
        case .retrievalFailed:
            return "Failed to retrieve item from keychain"
        case .deleteFailed:
            return "Failed to delete item from keychain"
        case .updateFailed:
            return "Failed to update existing keychain item"
        case .accessValidationFailed:
            return "Failed to validate keychain access"
        case .xpcConfigurationFailed:
            return "Failed to configure XPC sharing for keychain"
        }
    }
}
