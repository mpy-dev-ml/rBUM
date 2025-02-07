//
//  DevelopmentSecurityService+BookmarkManagement.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 7 February 2025
//

import Foundation
import os.log

@available(macOS 13.0, *)
public extension DevelopmentSecurityService {
    /// Creates a security-scoped bookmark for a URL.
    ///
    /// This method simulates bookmark creation by:
    /// - Checking for simulated failures
    /// - Adding artificial delays
    /// - Recording the creation attempt
    /// - Updating metrics
    ///
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: The bookmark data
    /// - Throws: `SecurityError.bookmarkCreationFailed` if creation fails
    func createBookmark(for url: URL) async throws -> Data {
        try simulator.simulateFailureIfNeeded(
            operation: "bookmark creation",
            url: url,
            error: { SecurityError.bookmarkCreationFailed($0) }
        )

        try await simulator.simulateDelay()

        // Simulate bookmark creation
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        // Store bookmark
        queue.async(flags: .barrier) {
            self.bookmarks[url] = bookmarkData
        }

        operationRecorder.recordOperation(
            url: url,
            type: .bookmarkCreation,
            status: .success
        )
        metrics.recordBookmarkCreation()

        logger.info(
            """
            Created bookmark for URL: \
            \(url.path)
            Active Bookmarks: \(metrics.activeBookmarkCount)
            """,
            file: #file,
            function: #function,
            line: #line
        )

        return bookmarkData
    }

    /// Resolves a security-scoped bookmark.
    ///
    /// This method simulates bookmark resolution by:
    /// - Checking for simulated failures
    /// - Adding artificial delays
    /// - Recording the resolution attempt
    /// - Updating metrics
    ///
    /// - Parameters:
    ///   - data: The bookmark data to resolve
    ///   - url: Optional URL to compare against
    /// - Returns: The resolved URL
    /// - Throws: `SecurityError.bookmarkResolutionFailed` if resolution fails
    func resolveBookmark(_ data: Data, against url: URL? = nil) async throws -> URL {
        try simulator.simulateFailureIfNeeded(
            operation: "bookmark resolution",
            url: url,
            error: { SecurityError.bookmarkResolutionFailed($0) }
        )

        try await simulator.simulateDelay()

        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if let url = url, resolvedURL != url {
            throw SecurityError.bookmarkResolutionFailed("URL mismatch")
        }

        operationRecorder.recordOperation(
            url: resolvedURL,
            type: .bookmarkResolution,
            status: .success
        )
        metrics.recordBookmarkResolution()

        logger.info(
            """
            Resolved bookmark for URL: \
            \(resolvedURL.path)
            Is Stale: \(isStale)
            """,
            file: #file,
            function: #function,
            line: #line
        )

        return resolvedURL
    }

    /// Starts accessing a security-scoped resource.
    ///
    /// This method simulates resource access by:
    /// - Checking for simulated failures
    /// - Adding artificial delays
    /// - Recording the access attempt
    /// - Updating metrics
    ///
    /// - Parameter url: The URL to access
    /// - Throws: `SecurityError.accessStartFailed` if access cannot be started
    func startAccessing(_ url: URL) async throws {
        try simulator.simulateFailureIfNeeded(
            operation: "start accessing",
            url: url,
            error: { SecurityError.accessStartFailed($0) }
        )

        try await simulator.simulateDelay()

        guard url.startAccessingSecurityScopedResource() else {
            throw SecurityError.accessStartFailed("Failed to start accessing resource")
        }

        operationRecorder.recordOperation(
            url: url,
            type: .accessStart,
            status: .success
        )
        metrics.recordAccessStart()

        logger.info(
            """
            Started accessing URL: \
            \(url.path)
            Active Access Count: \(metrics.activeAccessCount)
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }

    /// Stops accessing a security-scoped resource.
    ///
    /// This method simulates resource release by:
    /// - Adding artificial delays
    /// - Recording the release attempt
    /// - Updating metrics
    ///
    /// - Parameter url: The URL to stop accessing
    func stopAccessing(_ url: URL) async {
        try? await simulator.simulateDelay()

        url.stopAccessingSecurityScopedResource()

        operationRecorder.recordOperation(
            url: url,
            type: .accessStop,
            status: .success
        )
        metrics.recordAccessStop()

        logger.info(
            """
            Stopped accessing URL: \
            \(url.path)
            Active Access Count: \(metrics.activeAccessCount)
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }
}
