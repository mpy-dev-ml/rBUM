import Foundation

/// An enumeration of different types of security operations that can be performed.
///
/// `SecurityOperationType` categorises security operations into distinct types,
/// which helps with:
/// - Operation tracking and auditing
/// - Error handling and reporting
/// - Performance monitoring
/// - Security policy enforcement
///
/// Each type represents a specific category of security operation:
/// - `access`: Operations involving security-scoped resource access
/// - `permission`: Operations involving permission management
/// - `bookmark`: Operations involving security-scoped bookmarks
/// - `xpc`: Operations involving XPC service interactions
///
/// The enum conforms to `String` to support:
/// - Serialisation for logging
/// - String-based comparisons
/// - Human-readable representation
///
/// Example usage:
/// ```swift
/// // Creating security operations
/// let operation = SecurityOperation(
///     url: fileURL,
///     operationType: .access,
///     timestamp: Date(),
///     status: .success
/// )
///
/// // Pattern matching in switch statements
/// switch operation.operationType {
/// case .access:
///     try startAccessing(operation.url)
/// case .permission:
///     try requestPermission(for: operation.url)
/// case .bookmark:
///     try createBookmark(for: operation.url)
/// case .xpc:
///     try sendToXPCService(operation)
/// }
///
/// // String representation
/// logger.info("Performing \(operation.operationType.rawValue) operation")
/// ```
///
/// Implementation notes:
/// 1. Use the most specific type for the operation
/// 2. Consider security implications of each type
/// 3. Log operations appropriately by type
/// 4. Handle errors specific to each type
@available(macOS 13.0, *)
public enum SecurityOperationType: String {
    /// Represents an operation to access a security-scoped resource.
    ///
    /// This type is used when:
    /// - Starting resource access
    /// - Stopping resource access
    /// - Validating resource access
    ///
    /// Common scenarios:
    /// ```swift
    /// // Starting resource access
    /// let startAccess = SecurityOperation(
    ///     url: fileURL,
    ///     operationType: .access,
    ///     timestamp: Date(),
    ///     status: .inProgress
    /// )
    ///
    /// // Stopping resource access
    /// let stopAccess = SecurityOperation(
    ///     url: fileURL,
    ///     operationType: .access,
    ///     timestamp: Date(),
    ///     status: .success
    /// )
    /// ```
    ///
    /// Security considerations:
    /// - Always pair start/stop access calls
    /// - Validate access before operations
    /// - Clean up resources properly
    /// - Handle access timeouts
    case access

    /// Represents an operation to request or manage permissions.
    ///
    /// This type is used when:
    /// - Requesting new permissions
    /// - Validating existing permissions
    /// - Revoking permissions
    ///
    /// Common scenarios:
    /// ```swift
    /// // Requesting file access
    /// let requestAccess = SecurityOperation(
    ///     url: fileURL,
    ///     operationType: .permission,
    ///     timestamp: Date(),
    ///     status: .inProgress
    /// )
    ///
    /// // Revoking permissions
    /// let revokeAccess = SecurityOperation(
    ///     url: fileURL,
    ///     operationType: .permission,
    ///     timestamp: Date(),
    ///     status: .success
    /// )
    /// ```
    ///
    /// Security considerations:
    /// - Request minimal permissions
    /// - Handle user denials gracefully
    /// - Respect system restrictions
    /// - Document permission usage
    case permission

    /// Represents an operation involving security-scoped bookmarks.
    ///
    /// This type is used when:
    /// - Creating bookmarks
    /// - Resolving bookmarks
    /// - Managing bookmark persistence
    ///
    /// Common scenarios:
    /// ```swift
    /// // Creating a bookmark
    /// let createBookmark = SecurityOperation(
    ///     url: fileURL,
    ///     operationType: .bookmark,
    ///     timestamp: Date(),
    ///     status: .inProgress
    /// )
    ///
    /// // Resolving a bookmark
    /// let resolveBookmark = SecurityOperation(
    ///     url: fileURL,
    ///     operationType: .bookmark,
    ///     timestamp: Date(),
    ///     status: .success
    /// )
    /// ```
    ///
    /// Security considerations:
    /// - Handle stale bookmarks
    /// - Validate bookmark data
    /// - Secure bookmark storage
    /// - Clean up invalid bookmarks
    case bookmark

    /// Represents an operation involving XPC service interactions.
    ///
    /// This type is used when:
    /// - Communicating with XPC service
    /// - Managing XPC connections
    /// - Handling XPC errors
    ///
    /// Common scenarios:
    /// ```swift
    /// // Sending XPC message
    /// let sendMessage = SecurityOperation(
    ///     url: serviceURL,
    ///     operationType: .xpc,
    ///     timestamp: Date(),
    ///     status: .inProgress
    /// )
    ///
    /// // Handling XPC error
    /// let handleError = SecurityOperation(
    ///     url: serviceURL,
    ///     operationType: .xpc,
    ///     timestamp: Date(),
    ///     status: .failure,
    ///     error: "Connection interrupted"
    /// )
    /// ```
    ///
    /// Security considerations:
    /// - Validate XPC endpoints
    /// - Handle connection failures
    /// - Secure message passing
    /// - Monitor service health
    case xpc
}
