//
//  KeychainError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Errors that can occur during keychain operations
public enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case retrievalFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case updateFailed(status: OSStatus)
    case accessValidationFailed
    case xpcConfigurationFailed
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save item to keychain: \(status)"
        case .retrievalFailed(let status):
            return "Failed to retrieve item from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete item from keychain: \(status)"
        case .updateFailed(let status):
            return "Failed to update existing keychain item: \(status)"
        case .accessValidationFailed:
            return "Failed to validate keychain access"
        case .xpcConfigurationFailed:
            return "Failed to configure XPC sharing for keychain"
        }
    }
}
