//
//  SecurityServiceProtocol.swift
//  Core
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation

/// Protocol defining platform-agnostic security operations
public protocol SecurityServiceProtocol {
    /// Check if hardware security module is available
    var isSecureHardwareAvailable: Bool { get }
    
    /// Store credentials securely
    /// - Parameters:
    ///   - credentials: The credentials to store
    ///   - identifier: Unique identifier for the credentials
    ///   - accessGroup: Optional access group for shared access
    ///   - accessControl: Optional access control flags
    /// - Throws: SecurityError if storage fails
    func storeCredentials(
        _ credentials: Data,
        identifier: String,
        accessGroup: String?,
        accessControl: Any?
    ) throws
    
    /// Retrieve stored credentials
    /// - Parameters:
    ///   - identifier: Unique identifier for the credentials
    ///   - accessGroup: Optional access group for shared access
    /// - Returns: The stored credentials data
    /// - Throws: SecurityError if retrieval fails
    func retrieveCredentials(
        identifier: String,
        accessGroup: String?
    ) throws -> Data
    
    /// Delete stored credentials
    /// - Parameters:
    ///   - identifier: Unique identifier for the credentials to delete
    ///   - accessGroup: Optional access group for shared access
    /// - Throws: SecurityError if deletion fails
    func deleteCredentials(
        identifier: String,
        accessGroup: String?
    ) throws
    
    /// Update existing credentials
    /// - Parameters:
    ///   - credentials: The new credentials data
    ///   - identifier: Unique identifier for the credentials to update
    ///   - accessGroup: Optional access group for shared access
    /// - Throws: SecurityError if update fails
    func updateCredentials(
        _ credentials: Data,
        identifier: String,
        accessGroup: String?
    ) throws
    
    /// Check if credentials exist
    /// - Parameters:
    ///   - identifier: Unique identifier for the credentials
    ///   - accessGroup: Optional access group for shared access
    /// - Returns: True if credentials exist, false otherwise
    func hasCredentials(
        identifier: String,
        accessGroup: String?
    ) -> Bool
    
    /// Generate an encryption key
    /// - Parameters:
    ///   - bits: The size of the key in bits (128 or 256)
    ///   - persistKey: Whether to persist the key in secure storage
    ///   - identifier: Optional identifier for persisted key
    ///   - accessGroup: Optional access group for shared access
    /// - Returns: The generated key data
    /// - Throws: SecurityError if key generation fails
    func generateEncryptionKey(
        bits: Int,
        persistKey: Bool,
        identifier: String?,
        accessGroup: String?
    ) throws -> Data
    
    /// Retrieve a stored encryption key
    /// - Parameters:
    ///   - identifier: Identifier of the key to retrieve
    ///   - accessGroup: Optional access group for shared access
    /// - Returns: The stored key data
    /// - Throws: SecurityError if retrieval fails
    func retrieveEncryptionKey(
        identifier: String,
        accessGroup: String?
    ) throws -> Data
    
    /// Delete a stored encryption key
    /// - Parameters:
    ///   - identifier: Identifier of the key to delete
    ///   - accessGroup: Optional access group for shared access
    /// - Throws: SecurityError if deletion fails
    func deleteEncryptionKey(
        identifier: String,
        accessGroup: String?
    ) throws
    
    /// Securely encrypt data
    /// - Parameters:
    ///   - data: The data to encrypt
    ///   - key: The encryption key
    /// - Returns: The encrypted data
    /// - Throws: SecurityError if encryption fails
    func encrypt(_ data: Data, using key: Data) throws -> Data
    
    /// Securely decrypt data
    /// - Parameters:
    ///   - data: The encrypted data
    ///   - key: The decryption key
    /// - Returns: The decrypted data
    /// - Throws: SecurityError if decryption fails
    func decrypt(_ data: Data, using key: Data) throws -> Data
}

/// Errors that can occur during security operations
public enum SecurityError: LocalizedError {
    case credentialsNotFound
    case credentialsExists
    case invalidCredentials
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
    case accessDenied
    case hardwareSecurityUnavailable
    case biometricAuthFailed
    case userCancelled
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            return "The requested credentials were not found"
        case .credentialsExists:
            return "Credentials already exist for this identifier"
        case .invalidCredentials:
            return "The provided credentials are invalid"
        case .encryptionFailed:
            return "Failed to encrypt the data"
        case .decryptionFailed:
            return "Failed to decrypt the data"
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .accessDenied:
            return "Access to the security service was denied"
        case .hardwareSecurityUnavailable:
            return "Hardware security module is not available"
        case .biometricAuthFailed:
            return "Biometric authentication failed"
        case .userCancelled:
            return "Operation was cancelled by the user"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}

/// Extension providing default implementations for optional protocol methods
public extension SecurityServiceProtocol {
    var isSecureHardwareAvailable: Bool { false }
    
    func storeCredentials(
        _ credentials: Data,
        identifier: String,
        accessGroup: String?,
        accessControl: Any? = nil
    ) throws {
        try storeCredentials(
            credentials,
            identifier: identifier,
            accessGroup: accessGroup
        )
    }
    
    func generateEncryptionKey(bits: Int) throws -> Data {
        try generateEncryptionKey(
            bits: bits,
            persistKey: false,
            identifier: nil,
            accessGroup: nil
        )
    }
}
