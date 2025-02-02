//
//  SandboxManagerTests.swift
//  CoreTests
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Testing
import Foundation
@testable import Core

struct SandboxManagerTests {
    private let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SandboxManagerTests")
        .path
    
    @Test
    func testBookmarkManagement() async throws {
        let defaults = UserDefaults(suiteName: "test.sandbox")!
        let manager = SandboxManager(defaults: defaults)
        
        let testFilePath = (temporaryDirectory as NSString)
            .appendingPathComponent("bookmarkTest.txt")
        let url = URL(fileURLWithPath: testFilePath)
        
        // Create test file
        try FileManager.default.createDirectory(
            atPath: temporaryDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try "Bookmark test content".write(
            toFile: testFilePath,
            atomically: true,
            encoding: .utf8
        )
        
        // Test storing bookmark
        try manager.storeBookmark(
            for: url,
            identifier: "test.bookmark",
            readOnly: true
        )
        
        // Test resolving bookmark
        let resolvedURL = try manager.resolveBookmark(
            identifier: "test.bookmark",
            readOnly: true
        )
        #expect(resolvedURL.path == url.path)
        
        // Test accessing bookmarked resource
        let hasAccess = manager.startAccessing(resolvedURL)
        if hasAccess {
            #expect(manager.hasPermission(for: resolvedURL))
            manager.stopAccessing(resolvedURL)
        }
        
        // Test removing bookmark
        manager.removeBookmark(identifier: "test.bookmark")
        do {
            _ = try manager.resolveBookmark(identifier: "test.bookmark")
            #expect(false, "Expected error was not thrown")
        } catch {
            #expect(error is FileManagerError)
        }
        
        // Clean up
        try FileManager.default.removeItem(atPath: temporaryDirectory)
        defaults.removePersistentDomain(forName: "test.sandbox")
    }
    
    @Test
    func testPermissionManagement() async throws {
        let manager = SandboxManager()
        let testFilePath = (temporaryDirectory as NSString)
            .appendingPathComponent("permissionTest.txt")
        let url = URL(fileURLWithPath: testFilePath)
        
        // Create test file
        try FileManager.default.createDirectory(
            atPath: temporaryDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try "Permission test content".write(
            toFile: testFilePath,
            atomically: true,
            encoding: .utf8
        )
        
        // Test permission checks
        let hasPermission = manager.hasPermission(for: url)
        #expect(hasPermission)
        
        let permissionGranted = try await manager.requestPermission(for: url)
        #expect(permissionGranted)
        
        // Clean up
        try FileManager.default.removeItem(atPath: temporaryDirectory)
    }
}
