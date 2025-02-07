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

/// Protocol for managing security-scoped bookmarks
public protocol BookmarkServiceProtocol {
    /// Create a security-scoped bookmark for a URL
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: The bookmark data
    func createBookmark(for url: URL) throws -> Data

    /// Resolve a security-scoped bookmark
    /// - Parameter bookmark: The bookmark data to resolve
    /// - Returns: The resolved URL
    func resolveBookmark(_ bookmark: Data) throws -> URL

    /// Validate if a bookmark is still valid
    /// - Parameter bookmark: The bookmark data to validate
    /// - Returns: true if the bookmark is valid
    func validateBookmark(_ bookmark: Data) throws -> Bool

    /// Start accessing a security-scoped resource
    /// - Parameter url: The URL to access
    /// - Returns: true if access was granted
    func startAccessing(_ url: URL) throws -> Bool

    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    func stopAccessing(_ url: URL) async throws
}
