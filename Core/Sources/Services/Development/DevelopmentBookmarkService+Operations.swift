//
//  DevelopmentBookmarkService+Operations.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 7 February 2025
//

import Foundation

// MARK: - Bookmark Operations Extension

@available(macOS 13.0, *)
public extension DevelopmentBookmarkService {
    /// Create a new bookmark for the given URL
    /// - Parameter url: URL to create bookmark for
    /// - Returns: Data representing the bookmark
    /// - Throws: BookmarkError if creation fails
    func createBookmark(for url: URL) throws -> Data {
        try withThreadSafety {
            // Simulate potential failures
            if Double.random(in: 0 ... 1) < configuration.simulatedFailureRate {
                throw BookmarkError.creationFailed
            }

            let data = "simulated_bookmark_\(UUID().uuidString)".data(using: .utf8)!
            bookmarks[url] = BookmarkEntry(data: data)

            logger.debug("Created bookmark", metadata: [
                "url": "\(url.path)",
                "size": "\(data.count)",
            ])

            collectMetrics()
            return data
        }
    }

    /// Resolve a bookmark to its corresponding URL
    /// - Parameter bookmark: Bookmark data to resolve
    /// - Returns: URL the bookmark points to
    /// - Throws: BookmarkError if resolution fails
    func resolveBookmark(_ bookmark: Data) throws -> URL {
        try withThreadSafety {
            // Simulate potential failures
            if Double.random(in: 0 ... 1) < configuration.simulatedFailureRate {
                throw BookmarkError.resolutionFailed
            }

            guard let (url, _) = bookmarks.first(where: { $0.value.data == bookmark }) else {
                throw BookmarkError.invalidBookmark
            }

            logger.debug("Resolved bookmark", metadata: [
                "url": "\(url.path)",
            ])

            return url
        }
    }

    /// Validate a bookmark's data
    /// - Parameter bookmark: Bookmark data to validate
    /// - Returns: True if bookmark is valid
    /// - Throws: BookmarkError if validation fails
    func validateBookmark(_ bookmark: Data) throws -> Bool {
        try withThreadSafety {
            guard let (url, entry) = bookmarks.first(where: { $0.value.data == bookmark }) else {
                logger.warning(
                    "Bookmark validation failed: bookmark not found",
                    metadata: ["size": "\(bookmark.count)"]
                )
                throw BookmarkError.invalidBookmark
            }

            var updatedEntry = entry
            updatedEntry.validationCount += 1
            bookmarks[url] = updatedEntry

            logger.debug("Validated bookmark", metadata: [
                "url": "\(url.path)",
                "validation_count": "\(updatedEntry.validationCount)",
            ])

            collectMetrics()
            return true
        }
    }
}
