//
//  SandboxError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// An enumeration of errors that can occur during sandboxed operations.
///
/// `SandboxError` provides detailed error information for operations that
/// must comply with macOS sandbox restrictions, including:
/// - Resource access
/// - Bookmark management
/// - Permission handling
///
/// Each error case includes the URL that caused the error to help with:
/// - Error diagnosis
/// - User feedback
/// - Error recovery
/// - Security auditing
///
/// The enum conforms to `LocalizedError` to provide:
/// - User-friendly error messages
/// - System integration
/// - Error reporting
/// - Diagnostics support
///
/// Example usage:
/// ```swift
/// // Handling sandbox errors
/// do {
///     try await sandboxService.accessResource(at: fileURL)
/// } catch let error as SandboxError {
///     switch error {
///     case .accessDenied(let url):
///         logger.error("Access denied to: \(url.path)")
///         requestUserPermission(for: url)
///
///     case .bookmarkInvalid(let url):
///         logger.error("Invalid bookmark for: \(url.path)")
///         recreateBookmark(for: url)
///
///     case .bookmarkCreationFailed(let url):
///         logger.error("Failed to create bookmark for: \(url.path)")
///         handleBookmarkFailure(url)
///
///     default:
///         logger.error("Sandbox error: \(error.localizedDescription)")
///         showSandboxErrorAlert(error)
///     }
/// }
///
/// // Using error descriptions
/// let error = SandboxError.accessDenied(fileURL)
/// print(error.localizedDescription)
/// // "Access denied to /path/to/file"
/// ```
///
/// Implementation notes:
/// 1. Always handle all error cases
/// 2. Log error details
/// 3. Provide recovery options
/// 4. Consider security implications
public enum SandboxError: LocalizedError {
    /// Indicates that access to a sandboxed resource was denied.
    ///
    /// This error occurs when:
    /// - Insufficient permissions
    /// - Resource is outside sandbox
    /// - Security scope is invalid
    /// - System denies access
    ///
    /// Example:
    /// ```swift
    /// // Handling access denial
    /// guard hasAccess(to: url) else {
    ///     throw SandboxError.accessDenied(url)
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Check permissions
    /// 2. Request access
    /// 3. Verify scope
    /// 4. Handle denial
    ///
    /// - Parameter URL: The URL that was denied access
    case accessDenied(URL)
    
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
    ///     throw SandboxError.bookmarkInvalid(url)
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Verify bookmark data
    /// 2. Check resource
    /// 3. Recreate bookmark
    /// 4. Handle permissions
    ///
    /// - Parameter URL: The URL with the invalid bookmark
    case bookmarkInvalid(URL)
    
    /// Indicates that creating a security-scoped bookmark failed.
    ///
    /// This error occurs when:
    /// - URL is invalid
    /// - Resource doesn't exist
    /// - Insufficient permissions
    /// - System bookmark creation fails
    ///
    /// Example:
    /// ```swift
    /// // Handling bookmark creation
    /// do {
    ///     let bookmark = try createBookmark(for: url)
    /// } catch {
    ///     throw SandboxError.bookmarkCreationFailed(url)
    /// }
    /// ```
    ///
    /// Recovery steps:
    /// 1. Validate URL
    /// 2. Check permissions
    /// 3. Verify resource
    /// 4. Handle system state
    ///
    /// - Parameter URL: The URL for which bookmark creation failed
    case bookmarkCreationFailed(URL)
    
    /// A localised description of the error suitable for user display.
    ///
    /// This property provides a human-readable description of the error,
    /// including the path of the URL that caused the error.
    ///
    /// Format: "[Operation] failed for path: [Path]"
    ///
    /// Example:
    /// ```swift
    /// let error = SandboxError.accessDenied(fileURL)
    /// print(error.localizedDescription)
    /// // "Access denied to /path/to/file"
    /// ```
    ///
    /// Usage:
    /// - Display in error alerts
    /// - Log error details
    /// - Track error patterns
    /// - Report system state
    public var errorDescription: String? {
        switch self {
        case .accessDenied(let url):
            return "Access denied to \(url.path)"
        case .bookmarkInvalid(let url):
            return "Invalid bookmark for \(url.path)"
        case .bookmarkCreationFailed(let url):
            return "Failed to create bookmark for \(url.path)"
        }
    }
}

/// Extension providing user-friendly error descriptions.
///
/// This extension adds functionality to convert any error into a format
/// suitable for presentation to users, with special handling for:
/// - Localised errors
/// - System errors
/// - Custom error types
///
/// Implementation notes:
/// 1. Prioritises localised descriptions
/// 2. Handles all error types
/// 3. Provides consistent format
/// 4. Supports error tracking
public extension Error {
    /// Converts any error to a user-presentable format.
    ///
    /// This property provides a human-readable description of the error by:
    /// - Using localised descriptions when available
    /// - Falling back to standard descriptions when needed
    /// - Ensuring consistent error presentation
    ///
    /// Example usage:
    /// ```swift
    /// // Displaying error in alert
    /// catch let error {
    ///     alertController.message = error.userDescription
    /// }
    ///
    /// // Logging error details
    /// logger.error(error.userDescription)
    ///
    /// // Error reporting
    /// analytics.reportError(error.userDescription)
    /// ```
    ///
    /// Usage:
    /// - User interface alerts
    /// - Error logging
    /// - System reporting
    /// - Analytics tracking
    var userDescription: String {
        switch self {
        case let error as LocalizedError:
            return error.localizedDescription
        default:
            return localizedDescription
        }
    }
}
