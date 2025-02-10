//
//  SecurityServiceProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// A protocol that defines the interface for security-related operations in a sandboxed environment.
///
/// The `SecurityServiceProtocol` provides a standardised interface for:
/// - Managing security-scoped bookmarks
/// - Handling sandbox permissions
/// - Validating security contexts
/// - Managing resource access
///
/// Implementations must ensure proper handling of:
/// 1. Security-scoped bookmarks
/// 2. Sandbox permissions
/// 3. Resource access
/// 4. Error conditions
///
/// Example usage:
/// ```swift
/// let securityService: SecurityServiceProtocol = ...
///
/// do {
///     let bookmark = try securityService.createBookmark(for: fileURL)
///     try securityService.startAccessing(fileURL)
///     // Work with the file
///     securityService.stopAccessing(fileURL)
/// } catch {
///     print("Security operation failed: \(error)")
/// }
/// ```
@objc public protocol SecurityServiceProtocol: NSObjectProtocol {
    /// Request permission to access a URL
    ///
    /// - Parameter url: URL for which permission is requested
    /// - Returns: Whether permission was granted
    /// - Throws: SecurityError if permission request fails
    @objc func requestPermission(for url: URL) async throws -> Bool

    /// Create a security-scoped bookmark for a URL
    ///
    /// - Parameter url: URL for which to create a bookmark
    /// - Returns: Bookmark data
    /// - Throws: SecurityError if bookmark creation fails
    @objc func createBookmark(for url: URL) throws -> Data

    /// Validate a security-scoped bookmark
    ///
    /// - Parameters:
    ///   - bookmark: Bookmark data to validate
    ///   - url: URL for which the bookmark was created
    /// - Returns: Whether the bookmark is valid
    /// - Throws: SecurityError if validation fails
    @objc func validateBookmark(_ bookmark: Data, for url: URL) throws -> Bool

    /// Start accessing a URL
    ///
    /// - Parameter url: URL to access
    /// - Throws: SecurityError if access fails
    @objc func startAccessing(_ url: URL) throws

    /// Stop accessing a URL
    ///
    /// - Parameter url: URL to stop accessing
    @objc func stopAccessing(_ url: URL)
}
