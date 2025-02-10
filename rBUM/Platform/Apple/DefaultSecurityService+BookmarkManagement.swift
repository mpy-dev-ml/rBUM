import AppKit
import Core
import Foundation

extension DefaultSecurityService {
    // MARK: - Bookmark Management

    /// Creates a security-scoped bookmark for the specified URL.
    ///
    /// - Parameter url: The URL for which to create a bookmark
    /// - Returns: The created bookmark data
    /// - Throws: SecurityError if bookmark creation fails
    func createSecurityBookmark(for url: URL) async throws -> Data {
        // Create operation ID
        let operationId = UUID()

        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .bookmarkCreation,
                url: url
            )

            // Create bookmark
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            // Store bookmark
            try await bookmarkService.storeBookmark(bookmark, for: url)

            // Complete operation
            try await completeSecurityOperation(operationId, success: true)

            return bookmark

        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }

    /// Resolves a security-scoped bookmark for the specified URL.
    ///
    /// - Parameter url: The URL for which to resolve a bookmark
    /// - Returns: The resolved URL
    /// - Throws: SecurityError if bookmark resolution fails
    func resolveSecurityBookmark(for url: URL) async throws -> URL {
        // Create operation ID
        let operationId = UUID()

        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .bookmarkResolution,
                url: url
            )

            // Find bookmark
            guard let bookmark = try await bookmarkService.findBookmark(for: url) else {
                throw SecurityError.bookmarkNotFound("No bookmark found for URL")
            }

            // Resolve bookmark
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // Handle stale bookmark
            if isStale {
                // Create new bookmark
                let newBookmark = try await createSecurityBookmark(for: resolvedURL)

                // Update stored bookmark
                try await bookmarkService.updateBookmark(newBookmark, for: url)
            }

            // Complete operation
            try await completeSecurityOperation(operationId, success: true)

            return resolvedURL

        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }

    /// Deletes a security-scoped bookmark for the specified URL.
    ///
    /// - Parameter url: The URL for which to delete the bookmark
    /// - Throws: SecurityError if bookmark deletion fails
    func deleteSecurityBookmark(for url: URL) async throws {
        // Create operation ID
        let operationId = UUID()

        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .bookmarkDeletion,
                url: url
            )

            // Delete bookmark
            try await bookmarkService.deleteBookmark(for: url)

            // Complete operation
            try await completeSecurityOperation(operationId, success: true)

        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }

    /// Updates a security-scoped bookmark for the specified URL.
    ///
    /// - Parameters:
    ///   - url: The URL for which to update the bookmark
    ///   - newURL: The new URL to associate with the bookmark
    /// - Throws: SecurityError if bookmark update fails
    func updateSecurityBookmark(for url: URL, with newURL: URL) async throws {
        // Create operation ID
        let operationId = UUID()

        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .bookmarkUpdate,
                url: url
            )

            // Create new bookmark
            let newBookmark = try await createSecurityBookmark(for: newURL)

            // Update stored bookmark
            try await bookmarkService.updateBookmark(newBookmark, for: url)

            // Complete operation
            try await completeSecurityOperation(operationId, success: true)

        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }
}
