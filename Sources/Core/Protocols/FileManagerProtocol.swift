//
//  FileManagerProtocol.swift
//  Core
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation

/// Protocol defining platform-agnostic file system operations
public protocol FileManagerProtocol {
    /// Check if a file exists at the given path
    /// - Parameter path: The path to check
    /// - Returns: True if the file exists, false otherwise
    func fileExists(atPath path: String) -> Bool
    
    /// Check if a directory exists at the given path
    /// - Parameter path: The path to check
    /// - Returns: True if the directory exists, false otherwise
    func directoryExists(atPath path: String) -> Bool
    
    /// Create a directory at the specified path
    /// - Parameters:
    ///   - path: The path where the directory should be created
    ///   - createIntermediates: If true, create intermediate directories as needed
    ///   - attributes: Dictionary of attributes to set on the new directory
    /// - Throws: Error if directory creation fails
    func createDirectory(
        atPath path: String,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws
    
    /// Remove the item at the specified path
    /// - Parameter path: The path of the item to remove
    /// - Throws: Error if removal fails
    func removeItem(atPath path: String) throws
    
    /// Move an item from one location to another
    /// - Parameters:
    ///   - sourcePath: The current location of the item
    ///   - destinationPath: The new location for the item
    /// - Throws: Error if the move operation fails
    func moveItem(atPath sourcePath: String, toPath destinationPath: String) throws
    
    /// Copy an item from one location to another
    /// - Parameters:
    ///   - sourcePath: The path of the item to copy
    ///   - destinationPath: The path where the copy should be placed
    /// - Throws: Error if the copy operation fails
    func copyItem(atPath sourcePath: String, toPath destinationPath: String) throws
    
    /// Get the contents of a directory
    /// - Parameters:
    ///   - path: The directory to list
    ///   - keys: The resource keys to pre-fetch for better performance
    /// - Returns: Array of URLs for the directory contents
    /// - Throws: Error if the directory cannot be read
    func contentsOfDirectory(
        at path: String,
        includingPropertiesForKeys keys: [URLResourceKey]?
    ) throws -> [URL]
    
    /// Check if the app has permission to access the given URL
    /// - Parameter url: The URL to check
    /// - Returns: True if access is granted, false otherwise
    func hasAccessPermission(for url: URL) -> Bool
    
    /// Request access permission for a URL
    /// - Parameter url: The URL to request access for
    /// - Returns: True if permission was granted, false otherwise
    func requestAccessPermission(for url: URL) async throws -> Bool
    
    /// Start accessing a security-scoped resource
    /// - Parameter url: The URL of the resource
    /// - Returns: True if access was started successfully
    func startAccessingSecurityScopedResource(_ url: URL) -> Bool
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL of the resource
    func stopAccessingSecurityScopedResource(_ url: URL)
    
    /// Create a security-scoped bookmark for a URL
    /// - Parameters:
    ///   - url: The URL to create a bookmark for
    ///   - applicationScope: If true, bookmark will be application-scoped
    ///   - options: Additional options for bookmark creation
    /// - Returns: The bookmark data
    /// - Throws: Error if bookmark creation fails
    func bookmarkData(
        for url: URL,
        applicationScope: Bool,
        options: BookmarkCreationOptions
    ) throws -> Data
    
    /// Resolve a security-scoped bookmark
    /// - Parameters:
    ///   - bookmarkData: The bookmark data to resolve
    ///   - applicationScope: If true, bookmark is application-scoped
    ///   - options: Additional options for bookmark resolution
    /// - Returns: The resolved URL and whether the bookmark needs to be recreated
    /// - Throws: Error if bookmark resolution fails
    func url(
        byResolvingBookmarkData bookmarkData: Data,
        applicationScope: Bool,
        options: BookmarkResolutionOptions
    ) throws -> (url: URL, isStale: Bool)
}

/// Options for creating security-scoped bookmarks
public struct BookmarkCreationOptions: OptionSet {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    /// Bookmark will be security scoped
    public static let withSecurityScope = BookmarkCreationOptions(rawValue: 1 << 0)
    
    /// Bookmark will be read-only
    public static let securityScopeAllowOnlyReadAccess = BookmarkCreationOptions(rawValue: 1 << 1)
    
    /// Bookmark will persist after app relaunch
    public static let minimalBookmark = BookmarkCreationOptions(rawValue: 1 << 2)
}

/// Options for resolving security-scoped bookmarks
public struct BookmarkResolutionOptions: OptionSet {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    /// Resolve a security-scoped bookmark
    public static let withSecurityScope = BookmarkResolutionOptions(rawValue: 1 << 0)
    
    /// Resolve as read-only
    public static let securityScopeAllowOnlyReadAccess = BookmarkResolutionOptions(rawValue: 1 << 1)
}

/// Errors specific to file operations
public enum FileManagerError: LocalizedError {
    case accessDenied
    case bookmarkInvalid
    case bookmarkStale
    case fileNotFound
    case directoryNotFound
    case operationNotPermitted
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to the resource was denied"
        case .bookmarkInvalid:
            return "The bookmark data is invalid"
        case .bookmarkStale:
            return "The bookmark data is stale and needs to be recreated"
        case .fileNotFound:
            return "The specified file was not found"
        case .directoryNotFound:
            return "The specified directory was not found"
        case .operationNotPermitted:
            return "The operation is not permitted in the current security context"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}
