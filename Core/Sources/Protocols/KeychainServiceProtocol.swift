//
//  KeychainServiceProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Protocol for secure keychain operations
///
/// This protocol defines the interface for keychain operations that must be performed
/// in a secure manner, ensuring:
/// - Proper access control
/// - Data encryption
/// - Secure storage
/// - Error handling
@objc public protocol KeychainServiceProtocol: NSObjectProtocol {
    /// Save data to the keychain with sandbox-compliant access
    /// - Parameters:
    ///   - data: The data to save
    ///   - key: Unique identifier for the keychain item
    ///   - accessGroup: Optional access group for XPC service sharing
    /// - Throws: KeychainError if save fails or sandbox denies access
    /// - Note: Use appropriate access group to share with XPC service
    @objc func save(_ data: Data, for key: String, accessGroup: String?) throws

    /// Retrieve data from the keychain with sandbox-compliant access
    /// - Parameters:
    ///   - key: Unique identifier for the keychain item
    ///   - accessGroup: Optional access group for XPC service sharing
    /// - Returns: Retrieved data if found, nil if item doesn't exist
    /// - Throws: KeychainError if retrieval fails or sandbox denies access
    /// - Note: Must handle both main app and XPC service access patterns
    @objc func retrieve(for key: String, accessGroup: String?) throws -> Data?

    /// Delete data from the keychain with sandbox-compliant access
    /// - Parameters:
    ///   - key: Unique identifier for the keychain item to delete
    ///   - accessGroup: Optional access group for XPC service sharing
    /// - Throws: KeychainError if deletion fails or sandbox denies access
    /// - Note: Must clean up items from both main app and XPC service
    @objc func delete(for key: String, accessGroup: String?) throws

    /// Configure keychain sharing with XPC service
    /// - Parameter accessGroup: The access group to use for sharing
    /// - Throws: KeychainError if configuration fails
    /// - Note: Must be called before any XPC service operations
    @objc func configureXPCSharing(accessGroup: String) throws

    /// Validate XPC service keychain access
    /// - Parameter accessGroup: The access group to validate
    /// - Returns: true if XPC service has proper keychain access
    /// - Throws: KeychainError if validation fails
    @objc func validateXPCAccess(accessGroup: String) throws -> Bool
}
