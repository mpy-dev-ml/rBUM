//
//  TestResourceUtilities.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Core
import Foundation

/// Utilities for managing test resources
enum TestResourceUtilities {
    /// Creates a temporary test directory with the given name
    /// - Parameter name: The name of the directory
    /// - Returns: URL to the created directory
    static func createTemporaryDirectory(name: String) throws -> URL {
        let baseURL = try URL.temporaryTestDirectory(name: "test-resources")
        let directoryURL = baseURL.appendingPathComponent(name)
        
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        return directoryURL
    }
    
    /// Creates a test file with the given content
    /// - Parameters:
    ///   - name: The name of the file
    ///   - content: The content to write to the file
    ///   - directory: The directory to create the file in
    /// - Returns: URL to the created file
    static func createTestFile(
        name: String,
        content: String,
        in directory: URL
    ) throws -> URL {
        let fileURL = directory.appendingPathComponent(name)
        try content.write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )
        return fileURL
    }
    
    /// Creates a test file with random content
    /// - Parameters:
    ///   - name: The name of the file
    ///   - size: The size of the file in bytes
    ///   - directory: The directory to create the file in
    /// - Returns: URL to the created file
    static func createRandomTestFile(
        name: String,
        size: Int,
        in directory: URL
    ) throws -> URL {
        let fileURL = directory.appendingPathComponent(name)
        let data = Data((0..<size).map { _ in UInt8.random(in: 0...255) })
        try data.write(to: fileURL)
        return fileURL
    }
    
    /// Cleans up test resources at the given URLs
    /// - Parameter urls: The URLs to clean up
    static func cleanupTestResources(_ urls: URL...) {
        urls.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
    }
}
