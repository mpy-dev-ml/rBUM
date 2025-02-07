import Foundation

/// A model representing a security-related operation and its metadata.
///
/// `SecurityOperation` encapsulates all relevant information about a security operation,
/// including its type, status, timing, and any errors that occurred. This struct is used to:
/// - Track security operation history
/// - Monitor operation success/failure rates
/// - Debug security-related issues
/// - Generate security audit logs
///
/// The struct conforms to `Hashable` to support:
/// - Storage in sets and dictionaries
/// - Efficient comparison and deduplication
/// - Integration with system collections
///
/// Example usage:
/// ```swift
/// // Create a new operation
/// let operation = SecurityOperation(
///     url: fileURL,
///     operationType: .access,
///     timestamp: Date(),
///     status: .success
/// )
///
/// // Log the operation
/// logger.info("Security operation completed: \(operation)")
///
/// // Track failed operations
/// if operation.status == .failure {
///     logger.error("Operation failed: \(operation.error ?? "Unknown error")")
/// }
///
/// // Store in operation history
/// operationHistory.insert(operation)
/// ```
///
/// Implementation notes:
/// 1. All properties are immutable for thread safety
/// 2. Equality is based on URL, type, and timestamp
/// 3. Error messages should be localised
/// 4. Timestamps should use system time zone
@available(macOS 13.0, *)
public struct SecurityOperation: Hashable {
    /// The URL associated with the security operation.
    ///
    /// This URL represents the resource that was the target of the operation,
    /// such as:
    /// - File or directory path
    /// - Network resource location
    /// - System resource identifier
    ///
    /// The URL should be:
    /// - Absolute (not relative)
    /// - Properly encoded
    /// - Accessible within sandbox
    public let url: URL

    /// The type of security operation that was performed.
    ///
    /// This indicates what kind of operation was attempted, such as:
    /// - Resource access
    /// - Bookmark creation
    /// - Permission request
    /// - Security validation
    ///
    /// See `SecurityOperationType` for all available types.
    public let operationType: SecurityOperationType

    /// The timestamp when the operation was performed.
    ///
    /// This timestamp:
    /// - Uses system time zone
    /// - Has millisecond precision
    /// - Helps track operation timing
    ///
    /// Used for:
    /// - Auditing
    /// - Performance monitoring
    /// - Operation ordering
    /// - Rate limiting
    public let timestamp: Date

    /// The final status of the operation.
    ///
    /// This indicates:
    /// - Operation success/failure
    /// - Failure context
    /// - Recovery options
    ///
    /// See `SecurityOperationStatus` for all possible states.
    public let status: SecurityOperationStatus

    /// An optional error message if the operation failed.
    ///
    /// This message should:
    /// - Be user-readable
    /// - Include error context
    /// - Suggest recovery steps
    /// - Be localised
    ///
    /// The error is nil for successful operations.
    public let error: String?

    /// Creates a new SecurityOperation instance.
    ///
    /// This initialiser creates an immutable record of a security operation
    /// with all its associated metadata.
    ///
    /// - Parameters:
    ///   - url: The URL of the resource involved in the operation
    ///   - operationType: The type of security operation performed
    ///   - timestamp: When the operation occurred (defaults to current time)
    ///   - status: The final status of the operation
    ///   - error: Optional error message if the operation failed
    ///
    /// Example:
    /// ```swift
    /// let operation = SecurityOperation(
    ///     url: fileURL,
    ///     operationType: .bookmark,
    ///     timestamp: Date(),
    ///     status: .failure,
    ///     error: "Bookmark data is stale"
    /// )
    /// ```
    public init(
        url: URL,
        operationType: SecurityOperationType,
        timestamp: Date,
        status: SecurityOperationStatus,
        error: String? = nil
    ) {
        self.url = url
        self.operationType = operationType
        self.timestamp = timestamp
        self.status = status
        self.error = error
    }

    /// Compares two SecurityOperation instances for equality.
    ///
    /// Two operations are considered equal if they have the same:
    /// - URL (compared using URL equality)
    /// - Operation type (exact match)
    /// - Timestamp (compared to millisecond precision)
    ///
    /// Note: Status and error are not considered for equality
    /// as they represent operation outcomes rather than identity.
    ///
    /// - Parameters:
    ///   - lhs: The first operation to compare
    ///   - rhs: The second operation to compare
    /// - Returns: `true` if the operations are equal
    ///
    /// Example:
    /// ```swift
    /// let op1 = SecurityOperation(url: url, type: .access, timestamp: now)
    /// let op2 = SecurityOperation(url: url, type: .access, timestamp: now)
    /// let areEqual = op1 == op2 // true
    /// ```
    public static func == (lhs: SecurityOperation, rhs: SecurityOperation) -> Bool {
        lhs.url == rhs.url &&
            lhs.operationType == rhs.operationType &&
            lhs.timestamp == rhs.timestamp
    }

    /// Hashes the essential components of the operation.
    ///
    /// This method combines:
    /// - URL (using URL's hash value)
    /// - Operation type (using enum's hash value)
    /// - Timestamp (using Date's hash value)
    ///
    /// Note: Status and error are not included in the hash
    /// to maintain consistency with equality comparison.
    ///
    /// - Parameter hasher: The hasher to use for combining the components
    ///
    /// Example:
    /// ```swift
    /// var hasher = Hasher()
    /// operation.hash(into: &hasher)
    /// let hashValue = hasher.finalize()
    /// ```
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(operationType)
        hasher.combine(timestamp)
    }
}
