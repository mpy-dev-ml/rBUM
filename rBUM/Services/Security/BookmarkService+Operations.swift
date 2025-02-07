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
            do {
                // Check if already accessing
                if accessQueue.sync({ activeBookmarks[url] != nil }) {
                    logger.warning("Already accessing bookmark for \(url.path)")
                    return true
                }

                // Retrieve or create bookmark
                let bookmark = try await getOrCreateBookmark(for: url)

                var isStale = false
                var resolvedURL: URL?

                do {
                    resolvedURL = try URL(
                        resolvingBookmarkData: bookmark,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                } catch {
                    logger.error("Failed to resolve bookmark: \(error.localizedDescription)")
                    throw BookmarkError.resolutionFailed(error.localizedDescription)
                }

                guard let resolvedURL else {
                    logger.error("Failed to resolve bookmark URL")
                    throw BookmarkError.resolutionFailed("Failed to resolve URL")
                }

                // Handle stale bookmark
                if isStale {
                    logger.warning("Stale bookmark detected for \(url.path)")
                    // Create new bookmark
                    let newBookmark = try await createBookmark(for: url)
                    accessQueue.async(flags: .barrier) {
                        self.activeBookmarks[url] = BookmarkAccess(
                            startTime: Date(),
                            maxDuration: 300, // 5 minutes
                            bookmark: newBookmark
                        )
                    }
                } else {
                    accessQueue.async(flags: .barrier) {
                        self.activeBookmarks[url] = BookmarkAccess(
                            startTime: Date(),
                            maxDuration: 300, // 5 minutes
                            bookmark: bookmark
                        )
                    }
                }

                // Start accessing
                guard resolvedURL.startAccessingSecurityScopedResource() else {
                    logger.error("Failed to start accessing security-scoped resource")
                    throw BookmarkError.accessDenied
                }

                logger.info("Started accessing bookmark for \(url.path)")
                return true
            } catch {
                logger.error("Failed to start accessing bookmark: \(error.localizedDescription)")
                throw error
            }
        }
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
