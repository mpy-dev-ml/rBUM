//
//  BookmarkService.swift
//  rBUM
//
//  Created by Matthew Yeager on 01/02/2025.
//

import Foundation
import Core

/// Protocol for managing security-scoped bookmarks
protocol BookmarkServiceProtocol {
    /// Create a security-scoped bookmark for a URL
    /// - Parameters:
    ///   - url: The URL to create a bookmark for
    ///   - timeout: Optional timeout for the operation
    /// - Returns: The bookmark data
    func createBookmark(for url: URL, timeout: TimeInterval) async throws -> Data
    
    /// Resolve a security-scoped bookmark
    /// - Parameters:
    ///   - bookmarkData: The bookmark data to resolve
    ///   - timeout: Optional timeout for the operation
    /// - Returns: Tuple containing the resolved URL and whether the bookmark is stale
    func resolveBookmark(_ bookmarkData: Data, timeout: TimeInterval) async throws -> (url: URL, isStale: Bool)
    
    /// Refresh a stale bookmark
    /// - Parameters:
    ///   - url: The URL to refresh the bookmark for
    ///   - timeout: Optional timeout for the operation
    /// - Returns: The new bookmark data
    func refreshBookmark(for url: URL, timeout: TimeInterval) async throws -> Data
    
    /// Restore persisted bookmarks
    /// - Parameter timeout: Optional timeout for the operation
    func restoreBookmarks(timeout: TimeInterval) async throws
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL of the resource to stop accessing
    func stopAccessingResource(_ url: URL)
}

/// Service for managing security-scoped bookmarks
final class BookmarkService: BookmarkServiceProtocol {
    private let logger: LoggerProtocol
    private let persistenceService: BookmarkPersistenceServiceProtocol
    private let fileManager: FileManager
    
    init(
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "BookmarkService"),
        persistenceService: BookmarkPersistenceServiceProtocol = BookmarkPersistenceService(),
        fileManager: FileManager = .default
    ) {
        self.logger = logger
        self.persistenceService = persistenceService
        self.fileManager = fileManager
        
        logger.debug("Bookmark service initialised", privacy: .public)
    }
    
    func createBookmark(for url: URL, timeout: TimeInterval = 30) async throws -> Data {
        logger.debug("Creating bookmark for URL: \(url.path, privacy: .private)")
        
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            try await persistenceService.saveBookmark(bookmarkData, for: url)
            logger.info("Successfully created bookmark for: \(url.path, privacy: .private)")
            
            return bookmarkData
            
        } catch {
            logger.error("Failed to create bookmark: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }
    
    func resolveBookmark(_ bookmarkData: Data, timeout: TimeInterval = 30) async throws -> (url: URL, isStale: Bool) {
        logger.debug("Resolving bookmark for URL: \(bookmarkData, privacy: .private)")
        
        do {
            var isStale = false
            
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                logger.warning("Bookmark is stale for URL: \(url.path, privacy: .private)")
                throw BookmarkError.staleBookmark(url.path)
            }
            
            logger.info("Successfully resolved bookmark for: \(url.path, privacy: .private)")
            return (url, isStale)
            
        } catch {
            logger.error("Failed to resolve bookmark: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }
    
    func refreshBookmark(for url: URL, timeout: TimeInterval = 30) async throws -> Data {
        return try await withTimeout(timeout) {
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
        }
    }
    
    func restoreBookmarks(timeout: TimeInterval = 30) async throws {
        try await withTimeout(timeout) {
            do {
                let bookmarks = try await persistenceService.listBookmarks()
                for (url, bookmarkData) in bookmarks {
                    do {
                        let (resolvedURL, isStale) = try await resolveBookmark(bookmarkData)
                        if isStale {
                            _ = try await refreshBookmark(for: resolvedURL)
                        }
                    } catch {
                        logger.warning("Failed to restore bookmark for URL: \(url.path, privacy: .public)")
                        continue
                    }
                }
            } catch {
                logger.error("Failed to restore bookmarks: \(error.localizedDescription, privacy: .public)")
                throw BookmarkError.restorationFailed(error.localizedDescription)
            }
        }
    }
    
    func stopAccessingResource(_ url: URL) {
        if fileManager.isUbiquitousItem(at: url) {
            logger.debug("Skipping stop access for iCloud item: \(url.path, privacy: .public)")
            return
        }
        url.stopAccessingSecurityScopedResource()
        logger.debug("Stopped accessing resource: \(url.path, privacy: .public)")
    }
    
    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw BookmarkError.operationTimeout
            }
            
            let result = try await group.next()
            group.cancelAll()
            return result ?? {
                throw BookmarkError.operationTimeout
            }()
        }
    }
}

/// Errors that can occur during bookmark operations
enum BookmarkError: LocalizedError {
    case creationFailed(String)
    case resolutionFailed(String)
    case refreshFailed(String)
    case restorationFailed(String)
    case staleBookmark(String)
    case operationTimeout
    
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
        case .staleBookmark(let url):
            return "Bookmark is stale for URL: \(url)"
        case .operationTimeout:
            return "Operation timed out"
        }
    }
}
