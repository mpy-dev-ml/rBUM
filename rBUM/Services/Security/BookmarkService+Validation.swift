import Core
import Foundation

extension BookmarkService {
    // MARK: - Validation

    /// Validates a bookmark for a URL.
    ///
    /// - Parameter url: The URL to validate the bookmark for
    /// - Returns: True if the bookmark is valid
    /// - Throws: BookmarkError if validation fails
    public func validateBookmark(for url: URL) async throws -> Bool {
        try await measure("Validate Bookmark") {
            do {
                let bookmark = try await getOrCreateBookmark(for: url)
                var isStale = false

                _ = try URL(
                    resolvingBookmarkData: bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    logger.warning("Stale bookmark detected during validation for \(url.path)")
                    return false
                }

                logger.info("Successfully validated bookmark for \(url.path)")
                return true
            } catch {
                logger.error("Failed to validate bookmark: \(error.localizedDescription)")
                return false
            }
        }
    }

    /// Gets or creates a bookmark for a URL.
    ///
    /// - Parameter url: The URL to get or create a bookmark for
    /// - Returns: The bookmark data
    /// - Throws: BookmarkError if retrieval or creation fails
    func getOrCreateBookmark(for url: URL) async throws -> Data {
        if let bookmark = try? keychainService.retrieveBookmark(for: url) {
            return bookmark
        }
        return try await createBookmark(for: url)
    }
}
