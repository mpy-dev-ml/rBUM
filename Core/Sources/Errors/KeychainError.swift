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

/// An enumeration of errors that can occur during keychain operations.
///
/// `KeychainError` provides detailed error information for operations involving
/// the system keychain, including:
/// - Saving credentials
/// - Retrieving credentials
/// - Updating credentials
/// - Deleting credentials
/// - Access validation
/// - XPC configuration
///
/// Each error case includes relevant status information to help with:
/// - Error diagnosis
/// - System status reporting
/// - Error recovery
/// - Security auditing
///
/// The enum conforms to `LocalizedError` to provide:
/// - User-friendly error messages
/// - System status details
/// - Error reporting
/// - Diagnostics support
///
/// Example usage:
/// ```swift
/// // Handling keychain errors
/// do {
///     try await keychainService.saveCredentials(credentials)
/// } catch let error as KeychainError {
///     switch error {
///     case .saveFailed(let status):
///         logger.error("Save failed with status: \(status)")
///         handleKeychainError(status)
///
///     case .accessValidationFailed:
///         logger.error("Access validation failed")
///         requestKeychainAccess()
///
///     case .xpcConfigurationFailed:
///         logger.error("XPC configuration failed")
///         reconfigureXPCSharing()
///
///     default:
///         logger.error("Keychain error: \(error.localizedDescription)")
///         showKeychainErrorAlert(error)
///     }
/// }
///
/// // Using error descriptions
/// let error = KeychainError.saveFailed(status: errSecDuplicateItem)
/// print(error.localizedDescription)
/// // "Failed to save item to keychain: -25299"
/// ```
///
/// Implementation notes:
/// 1. Always check OSStatus codes
/// 2. Handle all error cases
/// 3. Provide clear error messages
/// 4. Log error details
public enum KeychainError: LocalizedError {
    /// Indicates that saving an item to the keychain failed.
    ///
    /// This error occurs when:
    /// - Item already exists
    /// - Insufficient permissions
    /// - Invalid item format
    /// - System keychain error
    ///
    /// Example:
    /// ```swift
    /// // Handling duplicate item
    /// if status == errSecDuplicateItem {
    ///     throw KeychainError.saveFailed(status: status)
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Check item uniqueness
    /// 2. Verify permissions
    /// 3. Validate data format
    /// 4. Handle system state
    ///
    /// - Parameter status: The OSStatus code indicating the specific error
    case saveFailed(status: OSStatus)
    
    /// Indicates that retrieving an item from the keychain failed.
    ///
    /// This error occurs when:
    /// - Item doesn't exist
    /// - Insufficient permissions
    /// - Invalid query format
    /// - System keychain error
    ///
    /// Example:
    /// ```swift
    /// // Handling missing item
    /// if status == errSecItemNotFound {
    ///     throw KeychainError.retrievalFailed(status: status)
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Verify item existence
    /// 2. Check permissions
    /// 3. Validate query
    /// 4. Handle system state
    ///
    /// - Parameter status: The OSStatus code indicating the specific error
    case retrievalFailed(status: OSStatus)
    
    /// Indicates that deleting an item from the keychain failed.
    ///
    /// This error occurs when:
    /// - Item doesn't exist
    /// - Insufficient permissions
    /// - Invalid query format
    /// - System keychain error
    ///
    /// Example:
    /// ```swift
    /// // Handling delete failure
    /// if status != errSecSuccess {
    ///     throw KeychainError.deleteFailed(status: status)
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Check item existence
    /// 2. Verify permissions
    /// 3. Validate query
    /// 4. Handle system state
    ///
    /// - Parameter status: The OSStatus code indicating the specific error
    case deleteFailed(status: OSStatus)
    
    /// Indicates that updating an existing keychain item failed.
    ///
    /// This error occurs when:
    /// - Item doesn't exist
    /// - Insufficient permissions
    /// - Invalid update format
    /// - System keychain error
    ///
    /// Example:
    /// ```swift
    /// // Handling update failure
    /// if status != errSecSuccess {
    ///     throw KeychainError.updateFailed(status: status)
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Verify item existence
    /// 2. Check permissions
    /// 3. Validate update data
    /// 4. Handle system state
    ///
    /// - Parameter status: The OSStatus code indicating the specific error
    case updateFailed(status: OSStatus)
    
    /// Indicates that validating keychain access failed.
    ///
    /// This error occurs when:
    /// - Keychain is locked
    /// - User denies access
    /// - Missing entitlements
    /// - System prevents access
    ///
    /// Example:
    /// ```swift
    /// // Handling access validation
    /// guard try await validateAccess() else {
    ///     throw KeychainError.accessValidationFailed
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Request user unlock
    /// 2. Check entitlements
    /// 3. Verify system state
    /// 4. Handle user denial
    case accessValidationFailed
    
    /// Indicates that configuring XPC sharing for the keychain failed.
    ///
    /// This error occurs when:
    /// - Invalid access group
    /// - Missing entitlements
    /// - XPC configuration error
    /// - System prevents sharing
    ///
    /// Example:
    /// ```swift
    /// // Handling XPC configuration
    /// guard try configureXPCSharing() else {
    ///     throw KeychainError.xpcConfigurationFailed
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Check access groups
    /// 2. Verify entitlements
    /// 3. Update configuration
    /// 4. Handle system state
    case xpcConfigurationFailed
    
    /// A localised description of the error suitable for user display.
    ///
    /// This property provides a human-readable description of the error,
    /// including any relevant status codes for system-level errors.
    ///
    /// Format: "[Operation] failed: [Details]"
    ///
    /// Example:
    /// ```swift
    /// let error = KeychainError.saveFailed(status: errSecDuplicateItem)
    /// print(error.localizedDescription)
    /// // "Failed to save item to keychain: -25299"
    /// ```
    ///
    /// Usage:
    /// - Display in error alerts
    /// - Log error details
    /// - Report system status
    /// - Track error patterns
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
