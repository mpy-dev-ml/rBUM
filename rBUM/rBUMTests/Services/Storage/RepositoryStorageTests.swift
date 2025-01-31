//
//  RepositoryStorageTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

struct RepositoryStorageTests {
    // MARK: - Test Setup
    
    private static func createTestStorage() throws -> (RepositoryStorage, URL) {
        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev.mpy.rBUM.tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let testURL = tempDir.appendingPathComponent("repositories.json")
        let storage = RepositoryStorage(fileManager: FileManager.default, storageURL: testURL)
        
        return (storage, testURL)
    }
    
    private static func cleanupTestStorage(_ url: URL) throws {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
    
    // MARK: - Basic Repository Tests
    
    @Test("Store and retrieve repository successfully", tags: ["basic", "storage"])
    func testStoreAndRetrieveRepository() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        let id = UUID()
        let repository = Repository(
            id: id,
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // Store repository
        try storage.store(repository)
        
        // Retrieve repository
        let retrieved = try storage.retrieve(forId: id)
        #expect(retrieved != nil)
        #expect(retrieved?.id == repository.id)
        #expect(retrieved?.name == repository.name)
        #expect(retrieved?.path == repository.path)
    }
    
    @Test("Update existing repository", tags: ["basic", "storage"])
    func testUpdateRepository() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        let id = UUID()
        let repository = Repository(
            id: id,
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
        let retrieved = try storage.retrieve(forId: id)
        #expect(retrieved != nil)
        #expect(retrieved?.name == "Updated Repo")
        
        // Verify only one entry exists
        let allRepositories = try storage.list()
        #expect(allRepositories.count == 1)
    }
    
    @Test("Delete repository successfully", tags: ["basic", "storage"])
    func testDeleteRepository() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        let id = UUID()
        let repository = Repository(
            id: id,
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // Store repository
        try storage.store(repository)
        
        // Delete repository
        try storage.delete(forId: id)
        
        // Verify deletion
        let retrieved = try storage.retrieve(forId: id)
        #expect(retrieved == nil)
        
        let allRepositories = try storage.list()
        #expect(allRepositories.isEmpty)
    }
    
    // MARK: - List Operations Tests
    
    @Test("List multiple repositories", tags: ["list", "storage"])
    func testListRepositories() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        let repository1 = Repository(
            id: UUID(),
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
        #expect(allRepositories.count == 2)
        #expect(allRepositories.contains { $0.name == "Test Repo 1" })
        #expect(allRepositories.contains { $0.name == "Test Repo 2" })
    }
    
    @Test("Empty storage returns empty array", tags: ["list", "storage"])
    func testEmptyStorageReturnsEmptyArray() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        let repositories = try storage.list()
        #expect(repositories.isEmpty)
    }
    
    // MARK: - Path Tests
    
    @Test("Check repository existence at path", tags: ["path", "storage"])
    func testExistsAtPath() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        let path = URL(fileURLWithPath: "/test/path")
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: path
        )
        
        // Initially should not exist
        #expect(!try storage.exists(atPath: path))
        
        // Store repository
        try storage.store(repository)
        
        // Should now exist
        #expect(try storage.exists(atPath: path))
    }
    
    @Test("Handle duplicate repository paths", tags: ["path", "error", "storage"])
    func testStoreRepositoryAtExistingPath() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        let path = URL(fileURLWithPath: "/test/path")
        let repository1 = Repository(
            id: UUID(),
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
        var thrownError: Error?
        do {
            try storage.store(repository2)
        } catch {
            thrownError = error
        }
        
        #expect(thrownError != nil)
        if let error = thrownError as? RepositoryStorageError {
            #expect(error == .repositoryAlreadyExists)
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Handle concurrent repository operations", tags: ["concurrency", "storage"])
    func testConcurrentAccess() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        // Create multiple repositories
        let repositories = (0..<5).map { i in
            Repository(
                id: UUID(),
                name: "Test Repo \(i)",
                path: URL(fileURLWithPath: "/test/path\(i)")
            )
        }
        
        // Concurrently store and retrieve repositories
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.mpy.rBUM.test", attributes: .concurrent)
        var errors: [Error] = []
        
        // Store repositories concurrently
        for repository in repositories {
            group.enter()
            queue.async {
                do {
                    try storage.store(repository)
                    _ = try storage.retrieve(forId: repository.id)
                } catch {
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        // Wait for all operations to complete
        group.wait()
        
        // Verify no errors occurred
        #expect(errors.isEmpty)
        
        // List all repositories
        let allRepositories = try storage.list()
        #expect(allRepositories.count == repositories.count)
        
        // Verify all repositories were stored correctly
        for repository in repositories {
            let retrieved = try storage.retrieve(forId: repository.id)
            #expect(retrieved != nil)
            #expect(retrieved?.id == repository.id)
            #expect(retrieved?.name == repository.name)
            #expect(retrieved?.path == repository.path)
        }
    }
    
    // MARK: - Parameterized Tests
    
    @Test("Handle various repository formats", tags: ["parameterized", "storage"])
    func testRepositoryFormats() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        let testCases = [
            // Test basic repository
            Repository(
                id: UUID(),
                name: "Basic Repository",
                path: URL(fileURLWithPath: "/basic/path")
            ),
            // Test repository with spaces in name and path
            Repository(
                id: UUID(),
                name: "Repository with spaces",
                path: URL(fileURLWithPath: "/path with spaces/repo")
            ),
            // Test repository with special characters
            Repository(
                id: UUID(),
                name: "Repository!@#$%^&*()",
                path: URL(fileURLWithPath: "/path/with/special/chars/!@#$/repo")
            ),
            // Test repository with very long name and path
            Repository(
                id: UUID(),
                name: String(repeating: "a", count: 100),
                path: URL(fileURLWithPath: "/very/long/path/" + String(repeating: "a", count: 100))
            ),
            // Test repository with minimum length name
            Repository(
                id: UUID(),
                name: "a",
                path: URL(fileURLWithPath: "/a")
            )
        ]
        
        for repository in testCases {
            // Store repository
            try storage.store(repository)
            
            // Retrieve and verify
            let retrieved = try storage.retrieve(forId: repository.id)
            #expect(retrieved != nil)
            #expect(retrieved?.id == repository.id)
            #expect(retrieved?.name == repository.name)
            #expect(retrieved?.path == repository.path)
            
            // Clean up
            try storage.delete(forId: repository.id)
        }
    }
    
    @Test("Handle file system edge cases", tags: ["error", "storage"])
    func testFileSystemEdgeCases() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // Test cases for file system edge cases
        let testCases = [
            // Test directory already exists
            {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                return repository
            }(),
            // Test file with no write permissions
            {
                try "".write(to: url, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
                return repository
            }(),
            // Test file in read-only directory
            {
                let readOnlyDir = url.deletingLastPathComponent()
                try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnlyDir.path)
                return repository
            }()
        ]
        
        for _ in testCases {
            var thrownError: Error?
            do {
                try storage.store(repository)
            } catch {
                thrownError = error
            }
            #expect(thrownError != nil)
            
            // Reset permissions for cleanup
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.deletingLastPathComponent().path)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
