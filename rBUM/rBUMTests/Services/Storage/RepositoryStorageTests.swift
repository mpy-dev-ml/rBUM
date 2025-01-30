//
//  RepositoryStorageTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
@testable import rBUM

final class RepositoryStorageTests: XCTestCase {
    var storage: RepositoryStorage!
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
        
        testURL = tempDir.appendingPathComponent("repositories.json")
        storage = RepositoryStorage(fileManager: FileManager.default, storageURL: testURL)
    }
    
    override func tearDown() async throws {
        if let testURL = testURL {
            try? FileManager.default.removeItem(at: testURL.deletingLastPathComponent())
        }
        storage = nil
        testURL = nil
        try await super.tearDown()
    }
    
    func testStoreAndRetrieveRepository() throws {
        let repository = Repository(
            id: testId,
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // Store repository
        try storage.store(repository)
        
        // Retrieve repository
        let retrieved = try storage.retrieve(forId: testId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, repository.id)
        XCTAssertEqual(retrieved?.name, repository.name)
        XCTAssertEqual(retrieved?.path, repository.path)
    }
    
    func testUpdateRepository() throws {
        let repository = Repository(
            id: testId,
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // Store initial repository
        try storage.store(repository)
        
        // Create updated repository with same ID
        var updatedRepository = repository
        updatedRepository.name = "Updated Repo"
        
        // Store updated repository
        try storage.store(updatedRepository)
        
        // Verify update
        let retrieved = try storage.retrieve(forId: testId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Updated Repo")
        
        // Verify only one entry exists
        let allRepositories = try storage.list()
        XCTAssertEqual(allRepositories.count, 1)
    }
    
    func testDeleteRepository() throws {
        let repository = Repository(
            id: testId,
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // Store repository
        try storage.store(repository)
        
        // Delete repository
        try storage.delete(forId: testId)
        
        // Verify deletion
        let retrieved = try storage.retrieve(forId: testId)
        XCTAssertNil(retrieved)
        
        let allRepositories = try storage.list()
        XCTAssertTrue(allRepositories.isEmpty)
    }
    
    func testListRepositories() throws {
        let repository1 = Repository(
            id: testId,
            name: "Test Repo 1",
            path: URL(fileURLWithPath: "/test/path1")
        )
        
        let repository2 = Repository(
            id: UUID(),
            name: "Test Repo 2",
            path: URL(fileURLWithPath: "/test/path2")
        )
        
        // Store multiple repositories
        try storage.store(repository1)
        try storage.store(repository2)
        
        // List all repositories
        let allRepositories = try storage.list()
        XCTAssertEqual(allRepositories.count, 2)
        XCTAssertTrue(allRepositories.contains { $0.name == "Test Repo 1" })
        XCTAssertTrue(allRepositories.contains { $0.name == "Test Repo 2" })
    }
    
    func testEmptyStorageReturnsEmptyArray() throws {
        let repositories = try storage.list()
        XCTAssertTrue(repositories.isEmpty)
    }
    
    func testExistsAtPath() throws {
        let path = URL(fileURLWithPath: "/test/path")
        let repository = Repository(
            id: testId,
            name: "Test Repo",
            path: path
        )
        
        // Initially should not exist
        XCTAssertFalse(try storage.exists(atPath: path))
        
        // Store repository
        try storage.store(repository)
        
        // Should now exist
        XCTAssertTrue(try storage.exists(atPath: path))
    }
    
    func testStoreRepositoryAtExistingPath() throws {
        let path = URL(fileURLWithPath: "/test/path")
        let repository1 = Repository(
            id: testId,
            name: "Test Repo 1",
            path: path
        )
        
        let repository2 = Repository(
            id: UUID(),
            name: "Test Repo 2",
            path: path
        )
        
        // Store first repository
        try storage.store(repository1)
        
        // Attempt to store second repository at same path
        XCTAssertThrowsError(try storage.store(repository2)) { error in
            XCTAssertEqual(error as? RepositoryStorageError, .repositoryAlreadyExists)
        }
    }
}
