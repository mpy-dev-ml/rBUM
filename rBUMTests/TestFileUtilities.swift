//
//  TestFileUtilities.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

@testable import Core
@testable import rBUM
import XCTest

extension XCTestCase {
    /// Creates a temporary file with a given name and content
    /// - Parameters:
    ///   - name: The name of the file
    ///   - content: The content of the file
    /// - Returns: URL of the created file
    /// - Throws: Error if file creation fails
    func createTemporaryFile(name: String, content: String) throws -> URL {
        let tempDir = try XCTUnwrap(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let fileURL = tempDir.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Creates a temporary directory
    /// - Parameter name: The name of the directory
    /// - Returns: URL of the created directory
    /// - Throws: Error if directory creation fails
    func createTemporaryDirectory(name: String) throws -> URL {
        let tempDir = try XCTUnwrap(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let dirURL = tempDir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL
    }
    
    /// Cleans up a temporary file or directory
    /// - Parameter url: The URL to clean up
    func cleanupTemporary(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
