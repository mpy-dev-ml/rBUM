import Foundation

/// An enumeration representing the status of a security operation.
///
/// `SecurityOperationStatus` provides a clear indication of whether a security
/// operation has succeeded, failed, or is still in progress. This helps with:
/// - Operation state tracking
/// - Error handling and recovery
/// - Progress monitoring
/// - User feedback
///
/// The enum conforms to `String` to support:
/// - Serialisation for logging
/// - Status persistence
/// - User interface display
/// - Status comparison
///
/// Status transitions typically follow this pattern:
/// ```
/// pending → success
///        ↘ failure
/// ```
///
/// Example usage:
/// ```swift
/// // Creating an operation
/// let operation = SecurityOperation(
///     url: fileURL,
///     operationType: .access,
///     timestamp: Date(),
///     status: .pending
/// )
///
/// // Handling different statuses
/// switch operation.status {
/// case .success:
///     logger.info("Access granted to \(operation.url)")
///     metrics.recordSuccess()
///
/// case .failure:
///     logger.error("Access denied: \(operation.error ?? "Unknown error")")
///     metrics.recordFailure()
///
/// case .pending:
///     logger.info("Waiting for access to \(operation.url)")
///     startProgressIndicator()
/// }
///
/// // Status-based UI updates
/// updateInterface(for: operation.status)
/// ```
///
/// Implementation notes:
/// 1. Always set an appropriate initial status
/// 2. Update status atomically with operation state
/// 3. Handle all status cases in switch statements
/// 4. Provide appropriate user feedback for each status
@available(macOS 13.0, *)
public enum SecurityOperationStatus: String {
    /// Indicates that the operation completed successfully.
    ///
    /// This status means:
    /// - The operation achieved its intended goal
    /// - No errors occurred during execution
    /// - Any resources were properly allocated/deallocated
    /// - The system is in a consistent state
    ///
    /// Example scenarios:
    /// ```swift
    /// // Successful file access
    /// let accessOp = SecurityOperation(
    ///     url: fileURL,
    ///     operationType: .access,
    ///     timestamp: Date(),
    ///     status: .success
    /// )
    ///
    /// // Successful permission grant
    /// let permissionOp = SecurityOperation(
    ///     url: resourceURL,
    ///     operationType: .permission,
    ///     timestamp: Date(),
    ///     status: .success
    /// )
    /// ```
    ///
    /// Best practices:
    /// - Verify operation completion
    /// - Clean up any resources
    /// - Update dependent operations
    /// - Log success details
    case success
    
    /// Indicates that the operation failed to complete.
    ///
    /// This status means:
    /// - The operation encountered an error
    /// - The intended goal was not achieved
    /// - Resources may need cleanup
    /// - Error recovery may be needed
    ///
    /// Example scenarios:
    /// ```swift
    /// // Failed bookmark resolution
    /// let bookmarkOp = SecurityOperation(
    ///     url: bookmarkURL,
    ///     operationType: .bookmark,
    ///     timestamp: Date(),
    ///     status: .failure,
    ///     error: "Bookmark data is stale"
    /// )
    ///
    /// // Failed XPC connection
    /// let xpcOp = SecurityOperation(
    ///     url: serviceURL,
    ///     operationType: .xpc,
    ///     timestamp: Date(),
    ///     status: .failure,
    ///     error: "Service connection timeout"
    /// )
    /// ```
    ///
    /// Best practices:
    /// - Include detailed error information
    /// - Clean up any partial state
    /// - Implement recovery strategies
    /// - Log failure details
    case failure
    
    /// Indicates that the operation is still in progress.
    ///
    /// This status means:
    /// - The operation has started but not completed
    /// - Resources are currently allocated
    /// - The final outcome is not yet known
    /// - The operation may need monitoring
    ///
    /// Example scenarios:
    /// ```swift
    /// // Ongoing permission request
    /// let permissionOp = SecurityOperation(
    ///     url: resourceURL,
    ///     operationType: .permission,
    ///     timestamp: Date(),
    ///     status: .pending
    /// )
    ///
    /// // Active XPC operation
    /// let xpcOp = SecurityOperation(
    ///     url: serviceURL,
    ///     operationType: .xpc,
    ///     timestamp: Date(),
    ///     status: .pending
    /// )
    /// ```
    ///
    /// Best practices:
    /// - Set appropriate timeouts
    /// - Monitor operation progress
    /// - Handle cancellation
    /// - Update status promptly
    case pending
}
