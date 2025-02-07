//
//  SecurityError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// An enumeration of errors that can occur during security-related operations.
///
/// `SecurityError` provides detailed error information for various security
/// operations, including:
/// - Permission management
/// - Bookmark operations
/// - Sandbox compliance
/// - Resource access
/// - XPC communication
///
/// Each error case includes a descriptive message to help with:
/// - Debugging issues
/// - User feedback
/// - Error logging
/// - Recovery handling
///
/// The enum conforms to:
/// - `LocalizedError` for user-friendly error messages
/// - `Equatable` for error comparison and testing
///
/// Example usage:
/// ```swift
/// // Handling security errors with switch
/// do {
///     try await securityService.requestPermission(for: fileURL)
/// } catch let error as SecurityError {
///     switch error {
///     case .permissionDenied(let message):
///         logger.error("Permission denied: \(message)")
///         showPermissionAlert()
///
///     case .sandboxViolation(let message):
///         logger.error("Sandbox violation: \(message)")
///         handleSandboxViolation()
///
///     case .bookmarkStale(let message):
///         logger.error("Stale bookmark: \(message)")
///         refreshBookmark()
///
///     default:
///         logger.error("Security error: \(error.localizedDescription)")
///         showErrorAlert(error)
///     }
/// }
///
/// // Using error descriptions
/// let error = SecurityError.accessDenied("File is locked")
/// print(error.localizedDescription) // "Access denied: File is locked"
///
/// // Comparing errors
/// if error == SecurityError.accessDenied("File is locked") {
///     // Handle specific error case
/// }
/// ```
///
/// Implementation notes:
/// 1. Always include descriptive error messages
/// 2. Use appropriate error cases for context
/// 3. Handle all error cases in switch statements
/// 4. Provide recovery suggestions where possible
public enum SecurityError: LocalizedError, Equatable {
    /// Indicates that permission was denied by the system's security mechanism.
    ///
    /// This error occurs when:
    /// - User denies permission request
    /// - System policy prevents access
    /// - Required entitlements are missing
    /// - Security settings block access
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.permissionDenied(
    ///     "User denied access to Documents folder"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Request permission again with clear purpose
    /// - Guide user to Security preferences
    /// - Check entitlements configuration
    /// - Verify security settings
    case permissionDenied(String)
    
    /// Indicates that creating a security-scoped bookmark failed.
    ///
    /// This error occurs when:
    /// - URL is invalid or inaccessible
    /// - Insufficient permissions
    /// - Resource doesn't exist
    /// - System cannot create bookmark
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.bookmarkCreationFailed(
    ///     "Cannot create bookmark for inaccessible file"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Verify resource exists
    /// - Check access permissions
    /// - Validate URL format
    /// - Request necessary permissions
    case bookmarkCreationFailed(String)
    
    /// Indicates that resolving an existing security-scoped bookmark failed.
    ///
    /// This error occurs when:
    /// - Bookmark data is corrupted
    /// - Resource no longer exists
    /// - Access permissions changed
    /// - System cannot resolve bookmark
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.bookmarkResolutionFailed(
    ///     "Bookmark data is corrupted or invalid"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Create new bookmark
    /// - Verify resource location
    /// - Check access permissions
    /// - Clean up invalid bookmarks
    case bookmarkResolutionFailed(String)
    
    /// Indicates that a security-scoped bookmark has become stale.
    ///
    /// This error occurs when:
    /// - Resource was moved or renamed
    /// - File system changed
    /// - Permissions were modified
    /// - System state changed
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.bookmarkStale(
    ///     "Bookmarked file was moved or renamed"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Recreate bookmark
    /// - Update resource path
    /// - Revalidate permissions
    /// - Clean up stale data
    case bookmarkStale(String)
    
    /// Indicates that an operation would violate sandbox restrictions.
    ///
    /// This error occurs when:
    /// - Attempting to access restricted resources
    /// - Exceeding sandbox permissions
    /// - Violating security boundaries
    /// - Breaking sandbox containment
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.sandboxViolation(
    ///     "Cannot access file outside sandbox"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Request user permission
    /// - Use security-scoped bookmarks
    /// - Check entitlements
    /// - Follow sandbox guidelines
    case sandboxViolation(String)
    
    /// Indicates that access to a resource was denied.
    ///
    /// This error occurs when:
    /// - Resource is protected
    /// - Permissions are insufficient
    /// - Security scope is invalid
    /// - Access token expired
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.accessDenied(
    ///     "File is locked by another process"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Request proper permissions
    /// - Refresh security scope
    /// - Check resource state
    /// - Handle access conflicts
    case accessDenied(String)
    
    /// Indicates that a required resource is not available or accessible.
    ///
    /// This error occurs when:
    /// - Resource doesn't exist
    /// - Resource is temporarily unavailable
    /// - System cannot access resource
    /// - Resource is locked
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.resourceUnavailable(
    ///     "Network share is temporarily offline"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Check resource existence
    /// - Wait and retry
    /// - Use alternative resource
    /// - Handle offline state
    case resourceUnavailable(String)
    
    /// Indicates that establishing an XPC connection failed.
    ///
    /// This error occurs when:
    /// - XPC service is not running
    /// - Connection timeout
    /// - Invalid service name
    /// - System prevents connection
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.xpcConnectionFailed(
    ///     "Service is not responding"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Restart XPC service
    /// - Check service status
    /// - Verify service name
    /// - Handle timeouts
    case xpcConnectionFailed(String)
    
    /// Indicates that the XPC service encountered an error during operation.
    ///
    /// This error occurs when:
    /// - Service crashes
    /// - Internal service error
    /// - Resource constraints
    /// - Operation timeout
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.xpcServiceError(
    ///     "Service terminated unexpectedly"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Restart operation
    /// - Check service logs
    /// - Monitor resources
    /// - Handle timeouts
    case xpcServiceError(String)
    
    /// Indicates that the XPC service denied permission for the requested operation.
    ///
    /// This error occurs when:
    /// - Service policy denies request
    /// - Invalid credentials
    /// - Operation not allowed
    /// - Security policy violation
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.xpcPermissionDenied(
    ///     "Operation requires elevated privileges"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Check credentials
    /// - Verify permissions
    /// - Update policy
    /// - Request elevation
    case xpcPermissionDenied(String)
    
    /// Indicates that XPC message validation failed.
    ///
    /// This error occurs when:
    /// - Invalid message format
    /// - Missing required data
    /// - Type mismatch
    /// - Security validation fails
    ///
    /// Example:
    /// ```swift
    /// throw SecurityError.xpcValidationFailed(
    ///     "Message missing required parameters"
    /// )
    /// ```
    ///
    /// Recovery suggestions:
    /// - Validate message format
    /// - Check required fields
    /// - Verify data types
    /// - Log validation details
    case xpcValidationFailed(String)
    
    /// A localised description of the error suitable for user display.
    ///
    /// This property provides a human-readable description of the error,
    /// including the specific error message provided when the error was created.
    ///
    /// The description format is: "[Error Type]: [Specific Message]"
    ///
    /// Example:
    /// ```swift
    /// let error = SecurityError.accessDenied("File is locked")
    /// print(error.localizedDescription) // "Access denied: File is locked"
    /// ```
    ///
    /// Usage notes:
    /// - Use for user interface display
    /// - Include in error alerts
    /// - Log with error details
    /// - Provide in support tickets
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .bookmarkCreationFailed(let message):
            return "Failed to create bookmark: \(message)"
        case .bookmarkResolutionFailed(let message):
            return "Failed to resolve bookmark: \(message)"
        case .bookmarkStale(let message):
            return "Bookmark is stale: \(message)"
        case .sandboxViolation(let message):
            return "Sandbox violation: \(message)"
        case .accessDenied(let message):
            return "Access denied: \(message)"
        case .resourceUnavailable(let message):
            return "Resource unavailable: \(message)"
        case .xpcConnectionFailed(let message):
            return "XPC connection failed: \(message)"
        case .xpcServiceError(let message):
            return "XPC service error: \(message)"
        case .xpcPermissionDenied(let message):
            return "XPC permission denied: \(message)"
        case .xpcValidationFailed(let message):
            return "XPC validation failed: \(message)"
        }
    }
}
