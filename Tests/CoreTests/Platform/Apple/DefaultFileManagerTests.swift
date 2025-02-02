//
//  DefaultFileManagerTests.swift
//  CoreTests
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Testing
import Foundation
@testable import Core

struct DefaultFileManagerTests {
    private let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("DefaultFileManagerTests")
        .path
    
    @Test
    func testFileOperations() async throws {
        let fileManager = DefaultFileManager()
        let testFilePath = (temporaryDirectory as NSString)
            .appendingPathComponent("testFile.txt")
        
        // Create temporary directory
        try fileManager.createDirectory(
            atPath: temporaryDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create test file
        try "Test content".write(
            toFile: testFilePath,
            atomically: true,
            encoding: .utf8
        )
        
        // Test file exists
        #expect(fileManager.fileExists(atPath: testFilePath))
        #expect(!fileManager.directoryExists(atPath: testFilePath))
        
        // Test directory exists
        #expect(!fileManager.fileExists(atPath: temporaryDirectory))
        #expect(fileManager.directoryExists(atPath: temporaryDirectory))
        
        // Test copy operation
        let copyPath = (temporaryDirectory as NSString)
            .appendingPathComponent("testFileCopy.txt")
        try fileManager.copyItem(atPath: testFilePath, toPath: copyPath)
        #expect(fileManager.fileExists(atPath: copyPath))
        
        // Test move operation
        let movePath = (temporaryDirectory as NSString)
            .appendingPathComponent("testFileMoved.txt")
        try fileManager.moveItem(atPath: copyPath, toPath: movePath)
        #expect(!fileManager.fileExists(atPath: copyPath))
        #expect(fileManager.fileExists(atPath: movePath))
        
        // Test directory contents
        let contents = try fileManager.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        )
        #expect(contents.count == 2)
        
        // Test removal
        try fileManager.removeItem(atPath: testFilePath)
        try fileManager.removeItem(atPath: movePath)
        #expect(!fileManager.fileExists(atPath: testFilePath))
        #expect(!fileManager.fileExists(atPath: movePath))
        
        // Clean up
        try fileManager.removeItem(atPath: temporaryDirectory)
    }
    
    @Test
    func testBookmarkOperations() async throws {
        let fileManager = DefaultFileManager()
        
        // Create a test file for bookmarking
        try fileManager.createDirectory(
            atPath: temporaryDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let testFilePath = (temporaryDirectory as NSString)
            .appendingPathComponent("bookmarkTest.txt")
        try "Bookmark test content".write(
            toFile: testFilePath,
            atomically: true,
            encoding: .utf8
        )
        
        // Test application-scoped bookmark
        let url = URL(fileURLWithPath: testFilePath)
        let bookmarkData = try fileManager.bookmarkData(
            for: url,
            applicationScope: true
        )
        
        let (resolvedURL, isStale) = try fileManager.url(
            byResolvingBookmarkData: bookmarkData,
            applicationScope: true
        )
        
        #expect(!isStale)
        #expect(resolvedURL.path == url.path)
        
        // Clean up
        try fileManager.removeItem(atPath: temporaryDirectory)
    }
    
    @Test
    func testSharedInstance() async throws {
        let shared1 = DefaultFileManager.shared
        let shared2 = DefaultFileManager.shared
        
        // Test that shared instance is actually shared
        #expect(ObjectIdentifier(shared1) == ObjectIdentifier(shared2))
    }
    
    @Test
    func testDirectoryCreationWithIntermediates() async throws {
        let fileManager = DefaultFileManager()
        let deepPath = (temporaryDirectory as NSString)
            .appendingPathComponent("level1/level2/level3")
        
        // Test creating nested directories
        try fileManager.createDirectory(
            atPath: deepPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        #expect(fileManager.directoryExists(atPath: deepPath))
        
        // Clean up
        try fileManager.removeItem(atPath: temporaryDirectory)
    }
    
    @Test
    func testSecurityScopedAccess() async throws {
        let fileManager = DefaultFileManager()
        let testFilePath = (temporaryDirectory as NSString)
            .appendingPathComponent("securityTest.txt")
        let url = URL(fileURLWithPath: testFilePath)
        
        // Create test file
        try "Test content".write(
            toFile: testFilePath,
            atomically: true,
            encoding: .utf8
        )
        
        // Test security-scoped access
        let hasAccess = fileManager.startAccessingSecurityScopedResource(url)
        if hasAccess {
            #expect(fileManager.hasAccessPermission(for: url))
            fileManager.stopAccessingSecurityScopedResource(url)
        }
        
        // Clean up
        try fileManager.removeItem(atPath: testFilePath)
    }
    
    @Test
    func testBookmarkWithOptions() async throws {
        let fileManager = DefaultFileManager()
        let testFilePath = (temporaryDirectory as NSString)
            .appendingPathComponent("bookmarkTest.txt")
        let url = URL(fileURLWithPath: testFilePath)
        
        // Create test file
        try "Bookmark test content".write(
            toFile: testFilePath,
            atomically: true,
            encoding: .utf8
        )
        
        // Create bookmark with options
        let options: BookmarkCreationOptions = [
            .withSecurityScope,
            .securityScopeAllowOnlyReadAccess,
            .minimalBookmark
        ]
        
        let bookmarkData = try fileManager.bookmarkData(
            for: url,
            applicationScope: true,
            options: options
        )
        
        // Resolve bookmark with options
        let resolutionOptions: BookmarkResolutionOptions = [
            .withSecurityScope,
            .securityScopeAllowOnlyReadAccess
        ]
        
        let (resolvedURL, isStale) = try fileManager.url(
            byResolvingBookmarkData: bookmarkData,
            applicationScope: true,
            options: resolutionOptions
        )
        
        #expect(!isStale)
        #expect(resolvedURL.path == url.path)
        
        // Clean up
        try fileManager.removeItem(atPath: testFilePath)
    }
    
    @Test
    func testAccessPermissions() async throws {
        let fileManager = DefaultFileManager()
        let testFilePath = (temporaryDirectory as NSString)
            .appendingPathComponent("permissionTest.txt")
        let url = URL(fileURLWithPath: testFilePath)
        
        // Create test file
        try "Permission test content".write(
            toFile: testFilePath,
            atomically: true,
            encoding: .utf8
        )
        
        // Test permission checks
        let hasPermission = fileManager.hasAccessPermission(for: url)
        #expect(hasPermission)
        
        let permissionGranted = try await fileManager.requestAccessPermission(for: url)
        #expect(permissionGranted)
        
        // Clean up
        try fileManager.removeItem(atPath: testFilePath)
    }
    
    @Test
    func testErrorHandling() async throws {
        let fileManager = DefaultFileManager()
        let nonexistentPath = (temporaryDirectory as NSString)
            .appendingPathComponent("doesNotExist")
        let url = URL(fileURLWithPath: nonexistentPath)
        
        // Test file not found error
        do {
            try fileManager.removeItem(atPath: nonexistentPath)
            #expect(false, "Expected error was not thrown")
        } catch let error as FileManagerError {
            #expect(error == .fileNotFound)
        }
        
        // Test invalid bookmark error
        do {
            _ = try fileManager.url(
                byResolvingBookmarkData: Data(),
                applicationScope: true,
                options: .withSecurityScope
            )
            #expect(false, "Expected error was not thrown")
        } catch let error as FileManagerError {
            #expect(error == .bookmarkInvalid)
        }
    }
}
