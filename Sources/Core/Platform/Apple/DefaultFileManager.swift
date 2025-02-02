//
//  DefaultFileManager.swift
//  Core
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation

/// A macOS implementation of FileManagerProtocol using Foundation's FileManager
public final class DefaultFileManager: FileManagerProtocol {
    /// The underlying FileManager instance
    private let fileManager: FileManager
    
    /// Set of URLs currently being accessed with security scope
    private var securityScopedURLs: Set<URL> = []
    
    /// Queue for synchronizing access to securityScopedURLs
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.filemanager")
    
    /// Creates a new DefaultFileManager instance
    /// - Parameter fileManager: The FileManager to use, defaults to .default
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    public func hasAccessPermission(for url: URL) -> Bool {
        // Check if we can read the contents of the URL
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            return fileManager.isReadableFile(atPath: url.path)
        }
        return false
    }
    
    public func requestAccessPermission(for url: URL) async throws -> Bool {
        // In macOS, we use security-scoped bookmarks for persistent access
        // This is a placeholder for potential future authorization requests
        return hasAccessPermission(for: url)
    }
    
    public func startAccessingSecurityScopedResource(_ url: URL) -> Bool {
        let result = url.startAccessingSecurityScopedResource()
        if result {
            queue.sync {
                securityScopedURLs.insert(url)
            }
        }
        return result
    }
    
    public func stopAccessingSecurityScopedResource(_ url: URL) {
        queue.sync {
            if securityScopedURLs.contains(url) {
                url.stopAccessingSecurityScopedResource()
                securityScopedURLs.remove(url)
            }
        }
    }
    
    public func fileExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue
    }
    
    public func directoryExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    public func createDirectory(
        atPath path: String,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
        do {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: createIntermediates,
                attributes: attributes
            )
        } catch {
            throw convertError(error)
        }
    }
    
    public func removeItem(atPath path: String) throws {
        do {
            try fileManager.removeItem(atPath: path)
        } catch {
            throw convertError(error)
        }
    }
    
    public func moveItem(atPath sourcePath: String, toPath destinationPath: String) throws {
        do {
            try fileManager.moveItem(atPath: sourcePath, toPath: destinationPath)
        } catch {
            throw convertError(error)
        }
    }
    
    public func copyItem(atPath sourcePath: String, toPath destinationPath: String) throws {
        do {
            try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
        } catch {
            throw convertError(error)
        }
    }
    
    public func contentsOfDirectory(
        at path: String,
        includingPropertiesForKeys keys: [URLResourceKey]?
    ) throws -> [URL] {
        let url = URL(fileURLWithPath: path)
        do {
            return try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: .skipsHiddenFiles
            )
        } catch {
            throw convertError(error)
        }
    }
    
    public func bookmarkData(
        for url: URL,
        applicationScope: Bool,
        options: BookmarkCreationOptions
    ) throws -> Data {
        var bookmarkOptions: URL.BookmarkCreationOptions = []
        
        if options.contains(.withSecurityScope) {
            bookmarkOptions.insert(.withSecurityScope)
        }
        if options.contains(.securityScopeAllowOnlyReadAccess) {
            bookmarkOptions.insert(.securityScopeAllowOnlyReadAccess)
        }
        if options.contains(.minimalBookmark) {
            bookmarkOptions.insert(.minimalBookmark)
        }
        
        do {
            return try url.bookmarkData(
                options: bookmarkOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw convertError(error)
        }
    }
    
    public func url(
        byResolvingBookmarkData bookmarkData: Data,
        applicationScope: Bool,
        options: BookmarkResolutionOptions
    ) throws -> (url: URL, isStale: Bool) {
        var bookmarkOptions: URL.BookmarkResolutionOptions = []
        
        if options.contains(.withSecurityScope) {
            bookmarkOptions.insert(.withSecurityScope)
        }
        if options.contains(.securityScopeAllowOnlyReadAccess) {
            bookmarkOptions.insert(.securityScopeAllowOnlyReadAccess)
        }
        
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: bookmarkOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        } catch {
            throw convertError(error)
        }
    }
    
    // MARK: - Private Helpers
    
    private func convertError(_ error: Error) -> FileManagerError {
        switch error {
        case CocoaError.fileNoSuchFile:
            return .fileNotFound
        case CocoaError.fileReadNoPermission,
             CocoaError.fileWriteNoPermission:
            return .accessDenied
        case CocoaError.fileReadInvalidBookmark:
            return .bookmarkInvalid
        case let nsError as NSError where nsError.domain == NSCocoaErrorDomain:
            switch nsError.code {
            case NSFileNoSuchFileError:
                return .fileNotFound
            case NSFileWriteNoPermissionError,
                 NSFileReadNoPermissionError:
                return .accessDenied
            default:
                return .unknown(error)
            }
        default:
            return .unknown(error)
        }
    }
    
    deinit {
        // Ensure all security-scoped resources are released
        queue.sync {
            securityScopedURLs.forEach { url in
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

// MARK: - Convenience Methods

public extension DefaultFileManager {
    /// Creates a default instance for the application
    static let shared = DefaultFileManager()
}
