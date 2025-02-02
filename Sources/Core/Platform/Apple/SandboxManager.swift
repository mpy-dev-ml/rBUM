//
//  SandboxManager.swift
//  Core
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation

/// Manages sandbox permissions and security-scoped bookmarks
public final class SandboxManager {
    /// Shared instance of the sandbox manager
    public static let shared = SandboxManager()
    
    /// The file manager to use for operations
    private let fileManager: FileManagerProtocol
    
    /// UserDefaults suite for storing bookmark data
    private let defaults: UserDefaults
    
    /// Queue for synchronizing bookmark operations
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.sandbox")
    
    /// Creates a new SandboxManager instance
    /// - Parameters:
    ///   - fileManager: The file manager to use
    ///   - defaults: UserDefaults suite for storing bookmarks
    public init(
        fileManager: FileManagerProtocol = DefaultFileManager.shared,
        defaults: UserDefaults = .standard
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
    }
    
    /// Store a security-scoped bookmark for future access
    /// - Parameters:
    ///   - url: The URL to bookmark
    ///   - identifier: Unique identifier for the bookmark
    ///   - readOnly: Whether the bookmark should be read-only
    /// - Throws: Error if bookmark creation fails
    public func storeBookmark(
        for url: URL,
        identifier: String,
        readOnly: Bool = false
    ) throws {
        var options: BookmarkCreationOptions = [.withSecurityScope]
        if readOnly {
            options.insert(.securityScopeAllowOnlyReadAccess)
        }
        
        let bookmarkData = try fileManager.bookmarkData(
            for: url,
            applicationScope: true,
            options: options
        )
        
        queue.sync {
            defaults.set(bookmarkData, forKey: bookmarkKey(for: identifier))
        }
    }
    
    /// Resolve a stored bookmark
    /// - Parameters:
    ///   - identifier: The identifier of the bookmark
    ///   - readOnly: Whether to resolve as read-only
    /// - Returns: The resolved URL if successful
    /// - Throws: Error if resolution fails
    public func resolveBookmark(
        identifier: String,
        readOnly: Bool = false
    ) throws -> URL {
        guard let bookmarkData = queue.sync(execute: {
            defaults.data(forKey: bookmarkKey(for: identifier))
        }) else {
            throw FileManagerError.bookmarkInvalid
        }
        
        var options: BookmarkResolutionOptions = [.withSecurityScope]
        if readOnly {
            options.insert(.securityScopeAllowOnlyReadAccess)
        }
        
        let (url, isStale) = try fileManager.url(
            byResolvingBookmarkData: bookmarkData,
            applicationScope: true,
            options: options
        )
        
        if isStale {
            // Update the bookmark
            try storeBookmark(
                for: url,
                identifier: identifier,
                readOnly: readOnly
            )
        }
        
        return url
    }
    
    /// Remove a stored bookmark
    /// - Parameter identifier: The identifier of the bookmark to remove
    public func removeBookmark(identifier: String) {
        queue.sync {
            defaults.removeObject(forKey: bookmarkKey(for: identifier))
        }
    }
    
    /// Start accessing a security-scoped resource
    /// - Parameter url: The URL to access
    /// - Returns: True if access was started successfully
    @discardableResult
    public func startAccessing(_ url: URL) -> Bool {
        fileManager.startAccessingSecurityScopedResource(url)
    }
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    public func stopAccessing(_ url: URL) {
        fileManager.stopAccessingSecurityScopedResource(url)
    }
    
    /// Check if we have permission to access a URL
    /// - Parameter url: The URL to check
    /// - Returns: True if we have permission
    public func hasPermission(for url: URL) -> Bool {
        fileManager.hasAccessPermission(for: url)
    }
    
    /// Request permission to access a URL
    /// - Parameter url: The URL to request access for
    /// - Returns: True if permission was granted
    public func requestPermission(for url: URL) async throws -> Bool {
        try await fileManager.requestAccessPermission(for: url)
    }
    
    // MARK: - Private Helpers
    
    private func bookmarkKey(for identifier: String) -> String {
        "bookmark.\(identifier)"
    }
}
