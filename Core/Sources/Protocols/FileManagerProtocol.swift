//
//  FileManagerProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Protocol for file system operations, allowing for easier testing and sandbox compliance
public protocol FileManagerProtocol {
    /// Check if a file exists at the given path
    func fileExists(atPath path: String) -> Bool
    
    /// Create a directory at the given URL
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
    
    /// Remove item at the given URL
    func removeItem(at url: URL) throws
    
    /// Get contents of a file at the given URL
    func contents(atPath path: String) -> Data?
    
    /// Write data to a file at the given URL
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool
}

/// Default implementation of FileManagerProtocol using FileManager
public struct DefaultFileManager: FileManagerProtocol {
    private let fileManager = FileManager.default
    
    public init() {}
    
    public func fileExists(atPath path: String) -> Bool {
        return fileManager.fileExists(atPath: path)
    }
    
    public func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }
    
    public func removeItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
    
    public func contents(atPath path: String) -> Data? {
        return fileManager.contents(atPath: path)
    }
    
    public func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool {
        return fileManager.createFile(atPath: path, contents: data, attributes: attr)
    }
}
