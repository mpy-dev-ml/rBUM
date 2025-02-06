//
//  BookmarkService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 01/02/2025.
//

import Foundation
import Core

/// Service for managing security-scoped bookmarks
public final class BookmarkService: BaseSandboxedService, BookmarkServiceProtocol, HealthCheckable {
    // MARK: - Properties
    private let keychainService: KeychainServiceProtocol
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.bookmarkService", attributes: .concurrent)
    private var activeBookmarks: [URL: BookmarkAccess] = [:]
    
    public var isHealthy: Bool {
        // Check if any bookmarks have been accessed for too long
        accessQueue.sync {
            !activeBookmarks.values.contains { $0.hasExceededMaxDuration }
        }
    }
    
    // MARK: - Types
    private struct BookmarkAccess {
        let startTime: Date
        let maxDuration: TimeInterval
        let bookmark: Data
        
        var hasExceededMaxDuration: Bool {
            Date().timeIntervalSince(startTime) > maxDuration
        }
    }
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        keychainService: KeychainServiceProtocol
    ) {
        self.keychainService = keychainService
        super.init(logger: logger, securityService: securityService)
    }
    
    // MARK: - BookmarkServiceProtocol Implementation
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
                
                guard let resolvedURL = resolvedURL else {
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
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Bookmark Service Health Check") {
            do {
                // Check keychain service health
                guard await keychainService.performHealthCheck() else {
                    return false
                }
                
                // Check for stuck bookmarks
                let stuckBookmarks = accessQueue.sync {
                    activeBookmarks.filter { $0.value.hasExceededMaxDuration }
                }
                
                if !stuckBookmarks.isEmpty {
                    logger.warning("Found \(stuckBookmarks.count) stuck bookmarks")
                    // Clean up stuck bookmarks
                    for (url, _) in stuckBookmarks {
                        stopAccessing(url)
                    }
                    return false
                }
                
                logger.info("Bookmark service health check passed")
                return true
            } catch {
                logger.error("Bookmark service health check failed: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    // MARK: - Private Helpers
    private func getOrCreateBookmark(for url: URL) async throws -> Data {
        if let bookmark = try? keychainService.retrieveBookmark(for: url) {
            return bookmark
        }
        return try await createBookmark(for: url)
    }
}

// MARK: - Bookmark Errors
public enum BookmarkError: LocalizedError {
    case creationFailed(String)
    case resolutionFailed(String)
    case accessDenied
    case invalidBookmark
    case bookmarkExpired
    
    public var errorDescription: String? {
        switch self {
        case .creationFailed(let message):
            return "Failed to create bookmark: \(message)"
        case .resolutionFailed(let message):
            return "Failed to resolve bookmark: \(message)"
        case .accessDenied:
            return "Access denied to security-scoped resource"
        case .invalidBookmark:
            return "Invalid bookmark data"
        case .bookmarkExpired:
            return "Bookmark has expired"
        }
    }
}
