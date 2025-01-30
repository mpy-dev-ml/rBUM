//
//  CredentialsStorageTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
@testable import rBUM

final class CredentialsStorageTests: XCTestCase {
    var storage: CredentialsStorage!
    var testURL: URL!
    let testId = UUID()
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev.mpy.rBUM.tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        testURL = tempDir.appendingPathComponent("credentials.json")
        storage = CredentialsStorage(fileManager: FileManager.default, storageURL: testURL)
    }
    
    override func tearDown() async throws {
        if let testURL = testURL {
            try? FileManager.default.removeItem(at: testURL.deletingLastPathComponent())
        }
        storage = nil
        testURL = nil
        try await super.tearDown()
    }
    
    func testStoreAndRetrieveCredentials() throws {
        let credentials = RepositoryCredentials(
            repositoryId: testId,
            repositoryPath: "/test/path"
        )
        
        // Store credentials
        try storage.store(credentials)
        
        // Retrieve credentials
        let retrieved = try storage.retrieve(forRepositoryId: testId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.repositoryId, credentials.repositoryId)
        XCTAssertEqual(retrieved?.repositoryPath, credentials.repositoryPath)
    }
    
    func testUpdateCredentials() throws {
        let credentials = RepositoryCredentials(
            repositoryId: testId,
            repositoryPath: "/test/path"
        )
        
        // Store initial credentials
        try storage.store(credentials)
        
        // Create updated credentials with same ID
        let updatedCredentials = RepositoryCredentials(
            repositoryId: testId,
            repositoryPath: "/new/path"
        )
        
        // Store updated credentials
        try storage.store(updatedCredentials)
        
        // Verify update
        let retrieved = try storage.retrieve(forRepositoryId: testId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.repositoryPath, "/new/path")
        
        // Verify only one entry exists
        let allCredentials = try storage.list()
        XCTAssertEqual(allCredentials.count, 1)
    }
    
    func testDeleteCredentials() throws {
        let credentials = RepositoryCredentials(
            repositoryId: testId,
            repositoryPath: "/test/path"
        )
        
        // Store credentials
        try storage.store(credentials)
        
        // Delete credentials
        try storage.delete(forRepositoryId: testId)
        
        // Verify deletion
        let retrieved = try storage.retrieve(forRepositoryId: testId)
        XCTAssertNil(retrieved)
        
        let allCredentials = try storage.list()
        XCTAssertTrue(allCredentials.isEmpty)
    }
    
    func testListCredentials() throws {
        let credentials1 = RepositoryCredentials(
            repositoryId: testId,
            repositoryPath: "/test/path1"
        )
        
        let credentials2 = RepositoryCredentials(
            repositoryId: UUID(),
            repositoryPath: "/test/path2"
        )
        
        // Store multiple credentials
        try storage.store(credentials1)
        try storage.store(credentials2)
        
        // List all credentials
        let allCredentials = try storage.list()
        XCTAssertEqual(allCredentials.count, 2)
        XCTAssertTrue(allCredentials.contains { $0.repositoryPath == "/test/path1" })
        XCTAssertTrue(allCredentials.contains { $0.repositoryPath == "/test/path2" })
    }
    
    func testEmptyStorageReturnsEmptyArray() throws {
        let credentials = try storage.list()
        XCTAssertTrue(credentials.isEmpty)
    }
}
