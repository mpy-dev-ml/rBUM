import Foundation

extension SecurityService {
    // MARK: - Bookmark Management

    /// Get active bookmark for a URL
    /// - Parameter url: URL to get bookmark for
    /// - Returns: Bookmark data if available
    func getActiveBookmark(for url: URL) -> Data? {
        bookmarkQueue.sync {
            activeBookmarks[url]
        }
    }

    /// Set active bookmark for a URL
    /// - Parameters:
    ///   - bookmark: Bookmark data to set
    ///   - url: URL to set bookmark for
    func setActiveBookmark(_ bookmark: Data, for url: URL) {
        bookmarkQueue.sync(flags: .barrier) {
            activeBookmarks[url] = bookmark
        }
    }

    /// Remove active bookmark for a URL
    /// - Parameter url: URL to remove bookmark for
    func removeActiveBookmark(for url: URL) {
        _ = bookmarkQueue.sync { activeBookmarks.removeValue(forKey: url) }
    }

    /// Create a security-scoped bookmark for a URL
    /// - Parameter url: URL to create bookmark for
    /// - Returns: Bookmark data
    /// - Throws: SecurityError if bookmark creation fails
    public func createBookmark(for url: URL) throws -> Data {
        logger.debug(
            "Creating bookmark for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmark
        } catch {
            throw SecurityError.bookmarkCreationFailed(error.localizedDescription)
        }
    }

    /// Resolve a security-scoped bookmark to a URL
    /// - Parameter bookmark: Bookmark data to resolve
    /// - Returns: Resolved URL
    /// - Throws: SecurityError if bookmark resolution fails or bookmark is stale
    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        logger.debug(
            "Resolving bookmark",
            file: #file,
            function: #function,
            line: #line
        )

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                logger.debug(
                    "Bookmark is stale",
                    file: #file,
                    function: #function,
                    line: #line
                )
                throw SecurityError.bookmarkStale("Bookmark needs to be recreated")
            }

            logger.debug(
                "Bookmark resolved successfully",
                file: #file,
                function: #function,
                line: #line
            )
            return url

        } catch {
            logger.error(
                "Failed to resolve bookmark: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.bookmarkResolutionFailed(error.localizedDescription)
        }
    }

    /// Persist access to a URL by creating and storing a bookmark
    /// - Parameter url: URL to persist access for
    /// - Returns: Created bookmark data
    /// - Throws: SecurityError if bookmark creation fails
    public func persistAccess(to url: URL) async throws -> Data {
        logger.debug(
            "Persisting access to: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        setActiveBookmark(bookmark, for: url)
        return bookmark
    }
}
