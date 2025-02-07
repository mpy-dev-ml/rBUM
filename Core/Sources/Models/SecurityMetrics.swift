import Foundation
import os.log

/// A struct that collects and manages security-related metrics for monitoring and debugging purposes.
///
/// `SecurityMetrics` tracks various security operations including:
/// - Access attempts and successes
/// - Permission requests
/// - Bookmark operations
/// - XPC service interactions
/// - Security failures
/// - Active access sessions
///
/// This metrics collection is particularly useful during development and testing to ensure
/// proper security behaviour and identify potential issues.
///
/// Example usage:
/// ```swift
/// var metrics = SecurityMetrics(logger: logger)
///
/// // Record successful operations
/// metrics.recordAccess()
/// metrics.recordPermission()
///
/// // Record failures with error messages
/// metrics.recordBookmark(success: false, error: "Invalid bookmark data")
/// metrics.recordXPC(success: false, error: "Service connection failed")
///
/// // Track active sessions
/// metrics.incrementActiveAccess()
/// // ... perform secured operations ...
/// metrics.recordAccessEnd()
/// ```
///
/// Implementation notes:
/// 1. Thread safety is not guaranteed - synchronisation must be handled externally
/// 2. Operation history is limited to the last 100 operations
/// 3. Active access count is prevented from going below 0
/// 4. All metrics are reset when the instance is deallocated
@available(macOS 13.0, *)
public struct SecurityMetrics {
    /// The total number of access attempts made.
    ///
    /// This count includes both successful and failed attempts to:
    /// - Access secured resources
    /// - Validate security scopes
    /// - Perform privileged operations
    private(set) var accessCount: Int = 0

    /// The total number of permission requests made.
    ///
    /// This count includes requests for:
    /// - File access permissions
    /// - Security-scoped bookmarks
    /// - System-level privileges
    private(set) var permissionCount: Int = 0

    /// The total number of bookmark operations performed.
    ///
    /// This count includes operations to:
    /// - Create bookmarks
    /// - Resolve bookmarks
    /// - Validate bookmark data
    private(set) var bookmarkCount: Int = 0

    /// The total number of XPC service interactions.
    ///
    /// This count includes:
    /// - Service connections
    /// - Message sends
    /// - Connection invalidations
    private(set) var xpcCount: Int = 0

    /// The total number of security operation failures.
    ///
    /// This count includes failures from:
    /// - Access attempts
    /// - Permission requests
    /// - Bookmark operations
    /// - XPC interactions
    private(set) var failureCount: Int = 0

    /// The current number of active access sessions.
    ///
    /// This count represents:
    /// - Open security scopes
    /// - Active permissions
    /// - Running privileged operations
    private(set) var activeAccessCount: Int = 0

    /// A chronological history of all security operations.
    ///
    /// This array:
    /// - Is limited to 100 entries
    /// - Removes oldest entries when full
    /// - Records operation details and timestamps
    private(set) var operationHistory: [SecurityOperation] = []

    /// The logger instance used for recording metric events.
    private let logger: Logger

    /// Initialises a new SecurityMetrics instance with the specified logger.
    ///
    /// - Parameter logger: The logger instance to use for recording metric events
    ///
    /// Example:
    /// ```swift
    /// let metrics = SecurityMetrics(
    ///     logger: Logger(subsystem: "dev.mpy.rBUM", category: "Security")
    /// )
    /// ```
    public init(logger: Logger) {
        self.logger = logger
    }

    /// Records an access attempt with an optional success status and error message.
    ///
    /// This method:
    /// 1. Increments the access count
    /// 2. Updates failure count if unsuccessful
    /// 3. Logs the attempt details
    ///
    /// - Parameters:
    ///   - success: Whether the access attempt was successful (default: `true`)
    ///   - error: An optional error message if the access attempt failed
    ///
    /// Example:
    /// ```swift
    /// metrics.recordAccess(success: false, error: "Access denied: insufficient permissions")
    /// ```
    mutating func recordAccess(success: Bool = true, error _: String? = nil) {
        accessCount += 1
        if !success { failureCount += 1 }
    }

    /// Records a permission request with an optional success status and error message.
    ///
    /// This method:
    /// 1. Increments the permission count
    /// 2. Updates failure count if unsuccessful
    /// 3. Logs the request details
    ///
    /// - Parameters:
    ///   - success: Whether the permission request was successful (default: `true`)
    ///   - error: An optional error message if the permission request failed
    ///
    /// Example:
    /// ```swift
    /// metrics.recordPermission(success: false, error: "User denied permission request")
    /// ```
    mutating func recordPermission(success: Bool = true, error _: String? = nil) {
        permissionCount += 1
        if !success { failureCount += 1 }
    }

    /// Records a bookmark operation with an optional success status and error message.
    ///
    /// This method:
    /// 1. Increments the bookmark count
    /// 2. Updates failure count if unsuccessful
    /// 3. Logs the operation details
    ///
    /// - Parameters:
    ///   - success: Whether the bookmark operation was successful (default: `true`)
    ///   - error: An optional error message if the bookmark operation failed
    ///
    /// Example:
    /// ```swift
    /// metrics.recordBookmark(success: false, error: "Bookmark data is stale")
    /// ```
    mutating func recordBookmark(success: Bool = true, error _: String? = nil) {
        bookmarkCount += 1
        if !success { failureCount += 1 }
    }

    /// Records an XPC service interaction with an optional success status and error message.
    ///
    /// This method:
    /// 1. Increments the XPC count
    /// 2. Updates failure count if unsuccessful
    /// 3. Logs the interaction details
    ///
    /// - Parameters:
    ///   - success: Whether the XPC service interaction was successful (default: `true`)
    ///   - error: An optional error message if the XPC service interaction failed
    ///
    /// Example:
    /// ```swift
    /// metrics.recordXPC(success: false, error: "XPC service connection interrupted")
    /// ```
    mutating func recordXPC(success: Bool = true, error _: String? = nil) {
        xpcCount += 1
        if !success { failureCount += 1 }
    }

    /// Records a security operation and adds it to the operation history.
    ///
    /// This method:
    /// 1. Adds the operation to history
    /// 2. Maintains history size limit
    /// 3. Records operation timestamp
    ///
    /// - Parameter operation: The security operation to record
    ///
    /// Example:
    /// ```swift
    /// let operation = SecurityOperation(type: .access, status: .success)
    /// metrics.recordOperation(operation)
    /// ```
    mutating func recordOperation(
        _ operation: SecurityOperation
    ) {
        operationHistory.append(operation)
        if operationHistory.count > 100 {
            operationHistory.removeFirst()
        }
    }

    /// Increments the active access session count.
    ///
    /// This method should be called when:
    /// - Starting a secured operation
    /// - Opening a security scope
    /// - Acquiring a new permission
    ///
    /// Example:
    /// ```swift
    /// metrics.incrementActiveAccess()
    /// try secureResource.startAccessing()
    /// ```
    mutating func incrementActiveAccess() {
        activeAccessCount += 1
    }

    /// Decrements the active access session count, ensuring it does not go below 0.
    ///
    /// This method should be called when:
    /// - Completing a secured operation
    /// - Closing a security scope
    /// - Releasing a permission
    ///
    /// Example:
    /// ```swift
    /// secureResource.stopAccessing()
    /// metrics.decrementActiveAccess()
    /// ```
    mutating func decrementActiveAccess() {
        activeAccessCount = max(0, activeAccessCount - 1)
    }

    /// Records the end of an access session and decrements the active access count.
    ///
    /// This method:
    /// 1. Decrements active access count
    /// 2. Ensures count doesn't go below 0
    /// 3. Updates metrics state
    ///
    /// Example:
    /// ```swift
    /// defer { metrics.recordAccessEnd() }
    /// try performSecuredOperation()
    /// ```
    mutating func recordAccessEnd() {
        decrementActiveAccess()
    }
}
