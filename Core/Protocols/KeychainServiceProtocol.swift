import Foundation

/// Protocol defining keychain operations with sandbox compliance
///
/// This protocol defines the interface for keychain operations that must be performed
/// within the app sandbox. All implementations must:
/// 1. Use app-specific keychain access groups
/// 2. Handle sandbox restrictions on keychain access
/// 3. Implement proper error handling for access denied scenarios
/// 4. Clean up keychain items when no longer needed
/// 5. Use appropriate keychain accessibility settings
/// 6. Support shared access between main app and XPC service
/// 7. Implement proper access control for XPC service
public protocol KeychainServiceProtocol {
    /// Save data to the keychain with sandbox-compliant access
    /// - Parameters:
    ///   - data: The data to save
    ///   - key: Unique identifier for the keychain item
    ///   - accessGroup: Optional access group for XPC service sharing
    /// - Throws: KeychainError if save fails or sandbox denies access
    /// - Note: Use appropriate access group to share with XPC service
    func save(_ data: Data, for key: String, accessGroup: String?) throws
    
    /// Retrieve data from the keychain with sandbox-compliant access
    /// - Parameters:
    ///   - key: Unique identifier for the keychain item
    ///   - accessGroup: Optional access group for XPC service sharing
    /// - Returns: Retrieved data if found, nil if item doesn't exist
    /// - Throws: KeychainError if retrieval fails or sandbox denies access
    /// - Note: Must handle both main app and XPC service access patterns
    func retrieve(for key: String, accessGroup: String?) throws -> Data?
    
    /// Delete data from the keychain with sandbox-compliant access
    /// - Parameters:
    ///   - key: Unique identifier for the keychain item to delete
    ///   - accessGroup: Optional access group for XPC service sharing
    /// - Throws: KeychainError if deletion fails or sandbox denies access
    /// - Note: Must clean up items from both main app and XPC service
    func delete(for key: String, accessGroup: String?) throws
    
    /// Configure keychain sharing with XPC service
    /// - Parameter accessGroup: The access group to use for sharing
    /// - Throws: KeychainError if configuration fails
    /// - Note: Must be called before any XPC service operations
    func configureXPCSharing(accessGroup: String) throws
    
    /// Validate XPC service keychain access
    /// - Parameter accessGroup: The access group to validate
    /// - Returns: true if XPC service has proper keychain access
    /// - Throws: KeychainError if validation fails
    func validateXPCAccess(accessGroup: String) throws -> Bool
}
