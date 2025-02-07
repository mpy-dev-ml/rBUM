//
//  ResticXPCError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Foundation

/// An enumeration of errors that can occur during Restic XPC service operations.
///
/// `ResticXPCError` provides detailed error information for operations involving
/// the Restic backup service over XPC, including:
/// - Service availability
/// - Connection management
/// - Command execution
/// - Bookmark handling
/// - Access control
/// - Timeout handling
/// - Version compatibility
///
/// Each error case includes relevant details to help with:
/// - Error diagnosis
/// - User feedback
/// - Error recovery
/// - Security auditing
///
/// The enum conforms to:
/// - `LocalizedError` for user-friendly error messages
/// - `Equatable` for error comparison and testing
///
/// Example usage:
/// ```swift
/// // Handling Restic XPC errors
/// do {
///     try await resticService.executeBackup(path: backupPath)
/// } catch let error as ResticXPCError {
///     switch error {
///     case .serviceUnavailable:
///         logger.error("Restic service is not running")
///         restartResticService()
///
///     case .executionFailed(let reason):
///         logger.error("Backup failed: \(reason)")
///         handleExecutionFailure(reason)
///
///     case .accessDenied(let path):
///         logger.error("Access denied to: \(path)")
///         requestAccessPermission(path)
///
///     case .timeout:
///         logger.error("Operation timed out")
///         retryWithLongerTimeout()
///
///     default:
///         logger.error("Restic error: \(error.localizedDescription)")
///         showResticErrorAlert(error)
///     }
/// }
///
/// // Error comparison
/// let error1 = ResticXPCError.accessDenied(path: "/backup")
/// let error2 = ResticXPCError.accessDenied(path: "/backup")
/// if error1 == error2 {
///     print("Same error condition")
/// }
/// ```
///
/// Implementation notes:
/// 1. Always handle all error cases
/// 2. Log error details
/// 3. Provide recovery options
/// 4. Consider security implications
public enum ResticXPCError: LocalizedError, Equatable {
    /// Indicates that the XPC service is not available.
    ///
    /// This error occurs when:
    /// - Service is not running
    /// - Service crashed
    /// - Service was terminated
    /// - System prevents service launch
    ///
    /// Example:
    /// ```swift
    /// // Handling service unavailability
    /// if !isServiceRunning {
    ///     throw ResticXPCError.serviceUnavailable
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Check service status
    /// 2. Attempt service restart
    /// 3. Verify system state
    /// 4. Handle user notification
    case serviceUnavailable

    /// Indicates that establishing an XPC connection failed.
    ///
    /// This error occurs when:
    /// - Connection timeout
    /// - Invalid service name
    /// - Missing entitlements
    /// - System prevents connection
    ///
    /// Example:
    /// ```swift
    /// // Handling connection failure
    /// guard let connection = establishConnection() else {
    ///     throw ResticXPCError.connectionFailed
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Verify service name
    /// 2. Check entitlements
    /// 3. Retry connection
    /// 4. Handle system state
    case connectionFailed

    /// Indicates that command execution failed.
    ///
    /// This error occurs when:
    /// - Invalid command
    /// - Command timeout
    /// - Resource constraints
    /// - System error
    ///
    /// Example:
    /// ```swift
    /// // Handling execution failure
    /// if exitCode != 0 {
    ///     throw ResticXPCError.executionFailed("Exit code: \(exitCode)")
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Validate command
    /// 2. Check resources
    /// 3. Handle timeout
    /// 4. Retry operation
    ///
    /// - Parameter reason: A description of why the execution failed
    case executionFailed(String)

    /// Indicates that a security-scoped bookmark is invalid.
    ///
    /// This error occurs when:
    /// - Bookmark data is corrupted
    /// - Invalid bookmark format
    /// - Resource doesn't exist
    /// - System cannot parse bookmark
    ///
    /// Example:
    /// ```swift
    /// // Handling invalid bookmark
    /// guard let bookmark = validateBookmark(data) else {
    ///     throw ResticXPCError.invalidBookmark(path: path)
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Verify bookmark data
    /// 2. Check resource
    /// 3. Recreate bookmark
    /// 4. Handle permissions
    ///
    /// - Parameter path: The path that caused the invalid bookmark
    case invalidBookmark(path: String)

    /// Indicates that a security-scoped bookmark is stale.
    ///
    /// This error occurs when:
    /// - Resource was moved
    /// - Resource was renamed
    /// - File system changed
    /// - Security state changed
    ///
    /// Example:
    /// ```swift
    /// // Handling stale bookmark
    /// if isBookmarkStale(bookmark) {
    ///     throw ResticXPCError.staleBookmark(path: path)
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Check resource state
    /// 2. Verify path
    /// 3. Update bookmark
    /// 4. Handle permissions
    ///
    /// - Parameter path: The path with the stale bookmark
    case staleBookmark(path: String)

    /// Indicates that access to a path was denied.
    ///
    /// This error occurs when:
    /// - Insufficient permissions
    /// - Resource is protected
    /// - Security scope is invalid
    /// - System denies access
    ///
    /// Example:
    /// ```swift
    /// // Handling access denial
    /// guard hasAccess(to: path) else {
    ///     throw ResticXPCError.accessDenied(path: path)
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Check permissions
    /// 2. Request access
    /// 3. Verify scope
    /// 4. Handle denial
    ///
    /// - Parameter path: The path that was denied access
    case accessDenied(path: String)

    /// Indicates that an operation timed out.
    ///
    /// This error occurs when:
    /// - Operation takes too long
    /// - System is unresponsive
    /// - Resource is unavailable
    /// - Network timeout
    ///
    /// Example:
    /// ```swift
    /// // Handling timeout
    /// if operationTime > timeout {
    ///     throw ResticXPCError.timeout
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Check duration
    /// 2. Verify resources
    /// 3. Adjust timeout
    /// 4. Retry operation
    case timeout

    /// Indicates that the XPC interface versions don't match.
    ///
    /// This error occurs when:
    /// - Client version is newer
    /// - Service version is newer
    /// - Version incompatibility
    /// - Protocol mismatch
    ///
    /// Example:
    /// ```swift
    /// // Handling version mismatch
    /// if clientVersion != serviceVersion {
    ///     throw ResticXPCError.interfaceVersionMismatch
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Check versions
    /// 2. Update client
    /// 3. Update service
    /// 4. Handle compatibility
    case interfaceVersionMismatch

    /// A localised description of the error suitable for user display.
    ///
    /// This property provides a human-readable description of the error,
    /// including any relevant paths or reasons for the failure.
    ///
    /// Format:
    /// - For path errors: "[Operation] failed for path: [Path]"
    /// - For execution errors: "[Operation] failed: [Reason]"
    /// - For state errors: "[State] error occurred"
    ///
    /// Example:
    /// ```swift
    /// let error = ResticXPCError.accessDenied(path: "/backup")
    /// print(error.localizedDescription)
    /// // "Access denied for path: /backup"
    /// ```
    ///
    /// Usage:
    /// - Display in error alerts
    /// - Log error details
    /// - Track error patterns
    /// - Report system state
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            "Restic XPC service is unavailable"
        case .connectionFailed:
            "Failed to establish XPC connection"
        case let .executionFailed(reason):
            "Command execution failed: \(reason)"
        case let .invalidBookmark(path):
            "Invalid security-scoped bookmark for path: \(path)"
        case let .staleBookmark(path):
            "Stale security-scoped bookmark for path: \(path)"
        case let .accessDenied(path):
            "Access denied for path: \(path)"
        case .timeout:
            "Operation timed out"
        case .interfaceVersionMismatch:
            "Interface version mismatch"
        }
    }

    /// Implementation of Equatable protocol for error comparison.
    ///
    /// This allows comparing error instances to determine if they represent
    /// the same error condition, which is useful for:
    /// - Error handling
    /// - Unit testing
    /// - Error tracking
    /// - State management
    ///
    /// Example:
    /// ```swift
    /// let error1 = ResticXPCError.timeout
    /// let error2 = ResticXPCError.timeout
    /// XCTAssertEqual(error1, error2)
    /// ```
    public static func == (left: ResticXPCError, right: ResticXPCError) -> Bool {
        switch (left, right) {
        case (.serviceUnavailable, .serviceUnavailable),
             (.connectionFailed, .connectionFailed),
             (.timeout, .timeout),
             (.interfaceVersionMismatch, .interfaceVersionMismatch):
            true

        case let (.executionFailed(leftReason), .executionFailed(rightReason)):
            leftReason == rightReason

        case let (.invalidBookmark(leftPath), .invalidBookmark(rightPath)):
            leftPath == rightPath

        case let (.staleBookmark(leftPath), .staleBookmark(rightPath)):
            leftPath == rightPath

        case let (.accessDenied(leftPath), .accessDenied(rightPath)):
            leftPath == rightPath

        default:
            false
        }
    }
}
