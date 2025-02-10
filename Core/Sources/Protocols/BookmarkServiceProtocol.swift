//
//  BookmarkServiceProtocol.swift
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

/// Protocol defining the interface for managing security-scoped bookmarks
///
/// This protocol provides methods for:
/// - Creating and resolving security-scoped bookmarks
/// - Managing bookmark access
/// - Validating bookmark data
/// - Handling bookmark errors
@objc public protocol BookmarkServiceProtocol: NSObjectProtocol {
    /// Create a security-scoped bookmark for a URL
    ///
    /// - Parameter url: URL to create bookmark for
    /// - Returns: Bookmark data
    /// - Throws: BookmarkError if creation fails
    @objc func createBookmark(for url: URL) throws -> Data

    /// Resolve a security-scoped bookmark to its URL
    ///
    /// - Parameter bookmark: Bookmark data to resolve
    /// - Returns: Resolved URL
    /// - Throws: BookmarkError if resolution fails
    @objc func resolveBookmark(_ bookmark: Data) throws -> URL

    /// Start accessing a bookmarked URL
    ///
    /// - Parameter url: URL to access
    /// - Returns: true if access was started
    /// - Throws: BookmarkError if access fails
    @objc func startAccessing(_ url: URL) throws -> Bool

    /// Stop accessing a bookmarked URL
    ///
    /// - Parameter url: URL to stop accessing
    @objc func stopAccessing(_ url: URL)

    /// Validate a security-scoped bookmark
    ///
    /// - Parameter bookmark: Bookmark data to validate
    /// - Returns: true if bookmark is valid
    /// - Throws: BookmarkError if validation fails
    @objc func validateBookmark(_ bookmark: Data) throws -> Bool

    /// Check if a URL is currently being accessed
    ///
    /// - Parameter url: URL to check
    /// - Returns: true if URL is being accessed
    @objc func isAccessing(_ url: URL) -> Bool
}
