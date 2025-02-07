//
//  KeychainService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation
import Security

/// Service for managing secure storage in the Keychain
public final class KeychainService: BaseSandboxedService, Measurable {
    // MARK: - Properties

    let queue: DispatchQueue
    public private(set) var isHealthy: Bool

    // MARK: - Initialization

    override public init(logger: LoggerProtocol, securityService: SecurityServiceProtocol) {
        queue = DispatchQueue(label: "dev.mpy.rBUM.keychain", qos: .userInitiated)
        isHealthy = true // Default to true, will be updated by health checks
        super.init(logger: logger, securityService: securityService)
    }
}

// MARK: - Keychain Errors

/// Errors that can occur during keychain operations
public enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case updateFailed(status: OSStatus)
    case retrievalFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case invalidData
    case accessDenied

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to keychain: \(status)"
        case .updateFailed(let status):
            return "Failed to update keychain item: \(status)"
        case .retrievalFailed(let status):
            return "Failed to retrieve from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from keychain: \(status)"
        case .invalidData:
            return "Invalid data format"
        case .accessDenied:
            return "Access denied to keychain"
        }
    }
}
