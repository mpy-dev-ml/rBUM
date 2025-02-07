//
//  BookmarkError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// An enumeration of errors that can occur during security-scoped bookmark operations.
///
/// `BookmarkError` provides detailed error information for operations involving
/// security-scoped bookmarks, including:
/// - Bookmark creation
/// - Bookmark resolution
/// - Bookmark validation
/// - Access control
///
/// Each error case includes the URL that caused the error to help with:
/// - Error diagnosis
/// - User feedback
/// - Error recovery
/// - Audit logging
///
/// The enum conforms to `LocalizedError` to provide:
/// - User-friendly error descriptions
/// - Technical failure reasons
/// - Recovery suggestions
/// - Localised messages
///
/// Example usage:
/// ```swift
/// // Creating and handling bookmark errors
/// do {
///     let bookmark = try bookmarkService.createBookmark(for: fileURL)
/// } catch let error as BookmarkError {
///     switch error {
///     case .creationFailed(let url):
///         logger.error("Failed to create bookmark: \(url.path)")
///         showErrorAlert(
///             title: error.localizedDescription,
///             message: error.recoverySuggestion ?? ""
///         )
///
///     case .accessDenied(let url):
///         logger.error("Access denied: \(url.path)")
///         requestUserPermission(for: url)
///
///     case .staleBookmark(let url):
///         logger.error("Stale bookmark: \(url.path)")
///         refreshBookmark(for: url)
///
///     default:
///         logger.error("Bookmark error: \(error.localizedDescription)")
///         handleGenericError(error)
///     }
/// }
///
/// // Using error properties
/// let error = BookmarkError.invalidBookmark(fileURL)
/// print(error.localizedDescription)  // User-friendly description
/// print(error.failureReason)         // Technical details
/// print(error.recoverySuggestion)    // Recovery steps
/// ```
///
/// Implementation notes:
/// 1. Always include the affected URL
/// 2. Provide clear error messages
/// 3. Include recovery steps
/// 4. Log error details
public enum BookmarkError: LocalizedError {
    /// Indicates that creating a security-scoped bookmark failed.
    ///
    /// This error occurs when:
    /// - The URL is invalid
    /// - The resource doesn't exist
    /// - Insufficient permissions
    /// - System bookmark creation fails
    ///
    /// Example:
    /// ```swift
    /// throw BookmarkError.creationFailed(fileURL)
    /// ```
    ///
    /// Recovery steps:
    /// 1. Verify resource exists
    /// 2. Check permissions
    /// 3. Request user access
    /// 4. Retry creation
    case creationFailed(URL)
    
    /// Indicates that resolving an existing bookmark failed.
    ///
    /// This error occurs when:
    /// - The bookmark data is corrupted
    /// - The resource was deleted
    /// - Permissions changed
    /// - System cannot resolve bookmark
    ///
    /// Example:
    /// ```swift
    /// throw BookmarkError.resolutionFailed(fileURL)
    /// ```
    ///
    /// Recovery steps:
    /// 1. Check resource existence
    /// 2. Verify permissions
    /// 3. Recreate bookmark
    /// 4. Update cached paths
    case resolutionFailed(URL)
    
    /// Indicates that a bookmark has become stale and needs recreation.
    ///
    /// This error occurs when:
    /// - The resource was moved
    /// - The resource was renamed
    /// - File system changed
    /// - Security state changed
    ///
    /// Example:
    /// ```swift
    /// throw BookmarkError.staleBookmark(fileURL)
    /// ```
    ///
    /// Recovery steps:
    /// 1. Locate current resource
    /// 2. Update bookmark data
    /// 3. Refresh access
    /// 4. Update references
    case staleBookmark(URL)
    
    /// Indicates that the bookmark data is invalid or corrupted.
    ///
    /// This error occurs when:
    /// - Bookmark data is malformed
    /// - Data integrity check fails
    /// - Bookmark format is invalid
    /// - System cannot parse bookmark
    ///
    /// Example:
    /// ```swift
    /// throw BookmarkError.invalidBookmark(fileURL)
    /// ```
    ///
    /// Recovery steps:
    /// 1. Delete invalid bookmark
    /// 2. Request new access
    /// 3. Create fresh bookmark
    /// 4. Update storage
    case invalidBookmark(URL)
    
    /// Indicates that access to the bookmarked resource was denied.
    ///
    /// This error occurs when:
    /// - Permissions are insufficient
    /// - Resource is protected
    /// - Security scope is invalid
    /// - System denies access
    ///
    /// Example:
    /// ```swift
    /// throw BookmarkError.accessDenied(fileURL)
    /// ```
    ///
    /// Recovery steps:
    /// 1. Request permissions
    /// 2. Verify security scope
    /// 3. Check resource state
    /// 4. Update access rights
    case accessDenied(URL)
    
    /// A localised description of the error suitable for user display.
    ///
    /// This property provides a human-readable description of the error,
    /// including the path of the URL that caused the error.
    ///
    /// Format: "[Error Type]: [Resource Path]"
    ///
    /// Example:
    /// ```swift
    /// let error = BookmarkError.accessDenied(fileURL)
    /// print(error.localizedDescription)
    /// // "Access denied to /Users/username/Documents/file.txt"
    /// ```
    ///
    /// Usage:
    /// - Display in error alerts
    /// - Show in status messages
    /// - Include in user feedback
    /// - Log for support
    public var errorDescription: String? {
        switch self {
        case .creationFailed(let url):
            return "Failed to create security-scoped bookmark for \(url.path)"
        case .resolutionFailed(let url):
            return "Failed to resolve security-scoped bookmark for \(url.path)"
        case .staleBookmark(let url):
            return "Security-scoped bookmark is stale for \(url.path)"
        case .invalidBookmark(let url):
            return "Invalid security-scoped bookmark for \(url.path)"
        case .accessDenied(let url):
            return "Access denied to \(url.path)"
        }
    }
    
    /// A detailed explanation of why the error occurred.
    ///
    /// This property provides technical details about the error that may be
    /// useful for debugging or logging purposes.
    ///
    /// Format: "Detailed technical explanation with context"
    ///
    /// Example:
    /// ```swift
    /// let error = BookmarkError.staleBookmark(fileURL)
    /// print(error.failureReason)
    /// // "The security-scoped bookmark for /path/to/file has become stale.
    /// // This can happen if the resource was moved or modified."
    /// ```
    ///
    /// Usage:
    /// - Debug logging
    /// - Technical support
    /// - Error investigation
    /// - System diagnostics
    public var failureReason: String? {
        switch self {
        case .creationFailed(let url):
            return """
                The system was unable to create a security-scoped bookmark for the file \
                or directory at \(url.path)
                """
        case .resolutionFailed(let url):
            return """
                The system was unable to resolve the security-scoped bookmark for \
                \(url.path). The bookmark may be corrupted or the resource may have \
                been moved.
                """
        case .staleBookmark(let url):
            return """
                The security-scoped bookmark for \(url.path) has become stale. \
                This can happen if the resource was moved or modified.
                """
        case .invalidBookmark(let url):
            return """
                The bookmark for \(url.path) is invalid. This can happen if the file \
                was moved or renamed. Please select the file again.
                """
        case .accessDenied(let url):
            return """
                The application does not have permission to access \(url.path). \
                The user may need to grant access.
                """
        }
    }
    
    /// A suggestion for how the user can recover from the error.
    ///
    /// This property provides a human-readable suggestion for how the user can
    /// recover from the error, including any necessary actions or steps.
    ///
    /// Format: "Clear instructions for error recovery"
    ///
    /// Example:
    /// ```swift
    /// let error = BookmarkError.accessDenied(fileURL)
    /// print(error.recoverySuggestion)
    /// // "Please grant access to /path/to/file when prompted."
    /// ```
    ///
    /// Usage:
    /// - User guidance
    /// - Error recovery
    /// - Help documentation
    /// - Support responses
    public var recoverySuggestion: String? {
        switch self {
        case .creationFailed(let url):
            return """
                Please ensure the application has permission to access \(url.path) \
                and try again.
                """
        case .resolutionFailed(let url):
            return """
                Try recreating the bookmark for \(url.path). If the issue persists, \
                the user may need to reselect the resource.
                """
        case .staleBookmark(let url):
            return """
                The security-scoped bookmark for \(url.path) has become stale. \
                This can happen if the resource was moved or modified.
                """
        case .invalidBookmark(let url):
            return """
                Please request access to \(url.path) again to create a new bookmark.
                """
        case .accessDenied(let url):
            return "Please grant access to \(url.path) when prompted."
        }
    }
}
