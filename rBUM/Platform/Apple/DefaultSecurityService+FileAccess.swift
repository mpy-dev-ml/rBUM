//
//  DefaultSecurityService+FileAccess.swift
//  rBUM
//
//  Created on 6 February 2025.
//

import Foundation

/// Extension to DefaultSecurityService handling file access and bookmark management
extension DefaultSecurityService {
    
    // MARK: - File Access Management
    
    private func hasSecurityScopedBookmark(
        for url: URL,
        permission: SecurityPermission
    ) async throws -> Bool {
        // Check if bookmark exists
        guard let bookmark = try? await bookmarkStore.getBookmark(for: url) else {
            return false
        }
        
        // Resolve bookmark
        var isStale = false
        guard let bookmarkURL = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return false
        }
        
        // Check if bookmark is stale
        if isStale {
            try await updateBookmark(for: url)
        }
        
        // Check if bookmark URL matches
        guard bookmarkURL == url else {
            return false
        }
        
        // Check permission
        return try await checkBookmarkPermission(permission, for: url)
    }
    
    private func updateBookmark(for url: URL) async throws {
        // Create new bookmark
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        // Store new bookmark
        try await bookmarkStore.storeBookmark(bookmark, for: url)
    }
    
    private func checkBookmarkPermission(
        _ permission: SecurityPermission,
        for url: URL
    ) async throws -> Bool {
        // Start accessing resource
        guard url.startAccessingSecurityScopedResource() else {
            return false
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Check permission
        switch permission {
        case .read:
            return try url.resourceValues(forKeys: [.isReadableKey]).isReadable ?? false
        case .write:
            return try url.resourceValues(forKeys: [.isWritableKey]).isWritable ?? false
        case .execute:
            return try url.resourceValues(forKeys: [.isExecutableKey]).isExecutable ?? false
        }
    }
    
    private func checkSecurityScopedAccess(to url: URL) async throws -> Bool {
        // Check if we have a security scoped bookmark
        guard let bookmark = try? await bookmarkService.findBookmark(for: url) else {
            return false
        }
        
        // Resolve bookmark
        var isStale = false
        guard let bookmarkURL = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return false
        }
        
        // Check if bookmark is stale
        if isStale {
            try await updateBookmark(for: url)
        }
        
        return bookmarkURL == url
    }
    
    private func validateDirectoryAccess(at url: URL) throws -> Bool {
        // Check directory permissions
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isReadableKey, .isWritableKey],
            options: [.skipsHiddenFiles]
        )
        
        // Check if all files are accessible
        for fileURL in contents {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isReadableKey, .isWritableKey])
            guard resourceValues.isReadable == true else {
                return false
            }
        }
        
        return true
    }
}
