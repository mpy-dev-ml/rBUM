//
//  BookmarkService.swift
//  rBUM
//
//  Created by Matthew Yeager on 01/02/2025.
//

import Foundation
import os

/// Protocol for managing security-scoped bookmarks
protocol BookmarkServiceProtocol {
    /// Create a security-scoped bookmark for a URL
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: The bookmark data
    func createBookmark(for url: URL) async throws -> Data
    
    /// Resolve a security-scoped bookmark
    /// - Parameter bookmarkData: The bookmark data to resolve
    /// - Returns: Tuple containing the resolved URL and whether the bookmark is stale
    func resolveBookmark(_ bookmarkData: Data) async throws -> (url: URL, isStale: Bool)
    
    /// Refresh a stale bookmark
    /// - Parameter url: The URL to refresh the bookmark for
    /// - Returns: The new bookmark data
    func refreshBookmark(for url: URL) async throws -> Data
    
    /// Restore persisted bookmarks
    func restoreBookmarks() async throws
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL of the resource to stop accessing
    func stopAccessingResource(_ url: URL)
}

/// Service for managing security-scoped bookmarks
final class BookmarkService: BookmarkServiceProtocol {
    private let logger: Logger
    private let persistenceService: BookmarkPersistenceServiceProtocol
    
    init(persistenceService: BookmarkPersistenceServiceProtocol = BookmarkPersistenceService()) {
        self.persistenceService = persistenceService
        self.logger = Logging.logger(for: .bookmarkService)
    }
    
    func createBookmark(for url: URL) async throws -> Data {
        logger.info("Creating bookmark for URL: \(url.path, privacy: .public)")
        return try await Task {
            do {
                let bookmarkData = try url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                try await persistenceService.persistBookmark(bookmarkData, forURL: url)
                return bookmarkData
            } catch {
                logger.error("Failed to create bookmark: \(error.localizedDescription, privacy: .public)")
                throw BookmarkError.creationFailed(error.localizedDescription)
            }
        }.value
    }
    
    func resolveBookmark(_ bookmarkData: Data) async throws -> (url: URL, isStale: Bool) {
        return try await Task {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    logger.warning("Bookmark is stale for URL: \(url.path, privacy: .public)")
                    if let refreshedData = try? await refreshBookmark(for: url) {
                        try await persistenceService.persistBookmark(refreshedData, forURL: url)
                    }
                }
                
                if !url.startAccessingSecurityScopedResource() {
                    logger.error("Failed to access security-scoped resource: \(url.path, privacy: .public)")
                    throw BookmarkError.accessDenied
                }
                
                return (url, isStale)
            } catch {
                logger.error("Failed to resolve bookmark: \(error.localizedDescription, privacy: .public)")
                throw BookmarkError.resolutionFailed(error.localizedDescription)
            }
        }.value
    }
    
    func refreshBookmark(for url: URL) async throws -> Data {
        logger.info("Refreshing bookmark for URL: \(url.path, privacy: .public)")
        return try await Task {
            do {
                let newBookmarkData = try url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                try await persistenceService.persistBookmark(newBookmarkData, forURL: url)
                return newBookmarkData
            } catch {
                logger.error("Failed to refresh bookmark: \(error.localizedDescription, privacy: .public)")
                throw BookmarkError.refreshFailed(error.localizedDescription)
            }
        }.value
    }
    
    func restoreBookmarks() async throws {
        logger.info("Restoring persisted bookmarks")
        try await Task {
            do {
                let bookmarks = try await persistenceService.listBookmarks()
                for (url, data) in bookmarks {
                    do {
                        let (resolvedURL, isStale) = try await resolveBookmark(data)
                        if isStale {
                            try await refreshBookmark(for: resolvedURL)
                        }
                    } catch {
                        logger.warning("Failed to restore bookmark for URL: \(url.path, privacy: .public)")
                        // Continue with other bookmarks even if one fails
                        continue
                    }
                }
            } catch {
                logger.error("Failed to restore bookmarks: \(error.localizedDescription, privacy: .public)")
                throw BookmarkError.restorationFailed(error.localizedDescription)
            }
        }.value
    }
    
    func stopAccessingResource(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
        logger.debug("Stopped accessing resource: \(url.path, privacy: .public)")
    }
}

/// Errors that can occur during bookmark operations
enum BookmarkError: LocalizedError {
    case creationFailed(String)
    case resolutionFailed(String)
    case refreshFailed(String)
    case restorationFailed(String)
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .creationFailed(let reason):
            return "Failed to create bookmark: \(reason)"
        case .resolutionFailed(let reason):
            return "Failed to resolve bookmark: \(reason)"
        case .refreshFailed(let reason):
            return "Failed to refresh bookmark: \(reason)"
        case .restorationFailed(let reason):
            return "Failed to restore bookmarks: \(reason)"
        case .accessDenied:
            return "Access denied to security-scoped resource"
        }
    }
}
