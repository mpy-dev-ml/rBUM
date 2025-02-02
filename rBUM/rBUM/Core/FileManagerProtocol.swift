//
//  FileManagerProtocol.swift
//  rBUM
//
//  Created by Matthew Yeager on 01/02/2025.
//

import Foundation

/// Protocol for file system operations
public protocol FileManagerProtocol {
    /// Create a directory at the specified URL
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws
    
    /// Remove the item at the specified URL
    func removeItem(at url: URL) throws
    
    /// Check if a file exists at the specified path
    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool
    
    /// Write data to a URL
    func write(_ data: Data, to url: URL) throws
    
    /// Read contents at path
    func contents(atPath path: String) -> Data?
    
    /// Get URL for search path directory
    func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor url: URL?, create: Bool) throws -> URL
}

extension FileManager: FileManagerProtocol {
    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
}
