import Core
import Foundation

extension BookmarkService {
    // MARK: - Operation Management

    /// Creates a new security-scoped bookmark for a URL.
    ///
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: The bookmark data
    /// - Throws: BookmarkError if creation fails
    public func createBookmark(for url: URL) async throws -> Data {
        try await measure("Create Bookmark") {
            do {
                let bookmark = try url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                // Store in keychain for persistence
                try keychainService.storeBookmark(bookmark, for: url)

                logger.info("Created bookmark for \(url.path)")
                return bookmark
            } catch {
                logger.error("Failed to create bookmark: \(error.localizedDescription)")
                throw BookmarkError.creationFailed(error.localizedDescription)
            }
        }
    }

    /// Starts accessing a security-scoped resource.
    ///
    /// - Parameter url: The URL to access
    /// - Returns: True if access was granted
    /// - Throws: BookmarkError if access fails
    public func startAccessing(_ url: URL) async throws -> Bool {
        try await measure("Start Accessing Bookmark") {
            // Check if already accessing
            if isActivelyAccessing(url) {
                logger.warning("Already accessing bookmark for \(url.path)")
                return true
            }

            // Get or create bookmark and resolve it
            let resolved = try await resolveBookmark(for: url)

            // Handle stale bookmark if needed
            let finalBookmark = try await handleStaleBookmarkIfNeeded(
                url: url,
                bookmark: resolved.data,
                isStale: resolved.isStale
            )

            // Start accessing the URL
            return try await startAccessingURL(resolved.url, bookmark: finalBookmark, originalURL: url)
        }
    }

    /// Checks if a URL is already being actively accessed
    private func isActivelyAccessing(_ url: URL) -> Bool {
        accessQueue.sync { activeBookmarks[url] != nil }
    }

    /// Result of resolving a bookmark
    private struct ResolvedBookmark {
        /// The resolved URL
        let url: URL
        /// The bookmark data
        let data: Data
        /// Whether the bookmark is stale
        let isStale: Bool
    }

    /// Resolves a bookmark for a URL
    /// - Parameter url: The URL to resolve bookmark for
    /// - Returns: The resolved bookmark information
    private func resolveBookmark(for url: URL) async throws -> ResolvedBookmark {
        let bookmark = try await getOrCreateBookmark(for: url)
        var isStale = false

        let resolvedURL = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        return ResolvedBookmark(
            url: resolvedURL,
            data: bookmark,
            isStale: isStale
        )
    }

    /// Handles stale bookmark if needed
    /// - Parameters:
    ///   - url: The original URL
    ///   - bookmark: The current bookmark data
    ///   - isStale: Whether the bookmark is stale
    /// - Returns: The final bookmark data to use
    private func handleStaleBookmarkIfNeeded(
        url: URL,
        bookmark: Data,
        isStale: Bool
    ) async throws -> Data {
        if isStale {
            logger.warning("Stale bookmark detected for \(url.path)")
            return try await createBookmark(for: url)
        }
        return bookmark
    }

    /// Starts accessing a resolved URL with a bookmark
    /// - Parameters:
    ///   - resolvedURL: The resolved URL to access
    ///   - bookmark: The bookmark data
    ///   - originalURL: The original URL
    /// - Returns: True if access was successful
    private func startAccessingURL(
        _ resolvedURL: URL,
        bookmark: Data,
        originalURL: URL
    ) async throws -> Bool {
        guard resolvedURL.startAccessingSecurityScopedResource() else {
            logger.error("Failed to start accessing security-scoped resource")
            throw BookmarkError.accessFailed
        }

        accessQueue.async(flags: .barrier) {
            self.activeBookmarks[originalURL] = BookmarkAccess(
                startTime: Date(),
                maxDuration: 300, // 5 minutes
                bookmark: bookmark
            )
        }

        return true
    }

    /// Stops accessing a security-scoped resource.
    ///
    /// - Parameter url: The URL to stop accessing
    public func stopAccessing(_ url: URL) {
        accessQueue.async(flags: .barrier) {
            if let access = self.activeBookmarks[url] {
                url.stopAccessingSecurityScopedResource()
                self.activeBookmarks.removeValue(forKey: url)
                self.logger.info("Stopped accessing bookmark for \(url.path)")
            } else {
                self.logger.warning("Attempted to stop accessing non-active bookmark for \(url.path)")
            }
        }
    }
}
