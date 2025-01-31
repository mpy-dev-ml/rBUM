//
//  RepositoryTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct RepositoryTests {
    // MARK: - Basic Tests
    
    @Test("Initialize repository with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let name = "Test Repository"
        let path = URL(fileURLWithPath: "/test/path")
        
        // When
        let repository = Repository(
            id: id,
            name: name,
            path: path
        )
        
        // Then
        #expect(repository.id == id)
        #expect(repository.name == name)
        #expect(repository.path == path)
        #expect(repository.createdAt.timeIntervalSinceNow <= 0)
        #expect(repository.modifiedAt.timeIntervalSinceNow <= 0)
        #expect(repository.lastBackupAt == nil)
        #expect(repository.lastCheckAt == nil)
        #expect(repository.lastPruneAt == nil)
        #expect(repository.status == .unknown)
    }
    
    @Test("Initialize repository with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let name = "Test Repository"
        let path = URL(fileURLWithPath: "/test/path")
        let createdAt = Date(timeIntervalSinceNow: -3600)
        let modifiedAt = Date(timeIntervalSinceNow: -1800)
        let lastBackupAt = Date(timeIntervalSinceNow: -900)
        let lastCheckAt = Date(timeIntervalSinceNow: -600)
        let lastPruneAt = Date(timeIntervalSinceNow: -300)
        let status = RepositoryStatus.ready
        
        // When
        let repository = Repository(
            id: id,
            name: name,
            path: path,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            lastBackupAt: lastBackupAt,
            lastCheckAt: lastCheckAt,
            lastPruneAt: lastPruneAt,
            status: status
        )
        
        // Then
        #expect(repository.id == id)
        #expect(repository.name == name)
        #expect(repository.path == path)
        #expect(repository.createdAt == createdAt)
        #expect(repository.modifiedAt == modifiedAt)
        #expect(repository.lastBackupAt == lastBackupAt)
        #expect(repository.lastCheckAt == lastCheckAt)
        #expect(repository.lastPruneAt == lastPruneAt)
        #expect(repository.status == status)
    }
    
    // MARK: - Status Tests
    
    @Test("Handle repository status changes", tags: ["model", "status"])
    func testStatusChanges() throws {
        let testCases: [(RepositoryStatus, String)] = [
            (.unknown, "Unknown"),
            (.initializing, "Initialising"),
            (.ready, "Ready"),
            (.locked, "Locked"),
            (.corrupted, "Corrupted"),
            (.maintenance, "Under Maintenance"),
            (.error("test error"), "Error: test error")
        ]
        
        for (status, description) in testCases {
            let repository = Repository(
                id: UUID(),
                name: "Test",
                path: URL(fileURLWithPath: "/test"),
                status: status
            )
            
            #expect(repository.status == status)
            #expect(repository.status.description == description)
        }
    }
    
    // MARK: - Path Tests
    
    @Test("Handle repository paths", tags: ["model", "path"])
    func testRepositoryPaths() throws {
        let testCases = [
            // Local paths
            "/test/path",
            "/Users/test/backups",
            "/Volumes/Backup/restic",
            // Network paths
            "sftp:user@host:/path",
            "s3:bucket-name:/path",
            "rest:http://localhost:8000/",
            // Paths with spaces and special characters
            "/test/path with spaces",
            "/test/path/with/special/chars/!@#$",
            // Very long paths
            "/very/long/path/" + String(repeating: "a", count: 1000)
        ]
        
        for pathString in testCases {
            let path = URL(string: pathString) ?? URL(fileURLWithPath: pathString)
            let repository = Repository(
                id: UUID(),
                name: "Test",
                path: path
            )
            
            #expect(repository.path == path)
        }
    }
    
    // MARK: - Timestamp Tests
    
    @Test("Handle repository timestamps", tags: ["model", "timestamp"])
    func testTimestamps() throws {
        // Given
        let repository = Repository(
            id: UUID(),
            name: "Test",
            path: URL(fileURLWithPath: "/test")
        )
        
        // Initial timestamps
        let now = Date()
        #expect(abs(repository.createdAt.timeIntervalSince(now)) < 1.0)
        #expect(abs(repository.modifiedAt.timeIntervalSince(now)) < 1.0)
        #expect(repository.createdAt == repository.modifiedAt)
        
        // Sleep to ensure time difference
        Thread.sleep(forTimeInterval: 0.1)
        
        // When updating
        var updated = repository
        updated.name = "Updated Test"
        
        // Then timestamps should reflect the change
        #expect(updated.createdAt == repository.createdAt)
        #expect(updated.modifiedAt > repository.modifiedAt)
        #expect(updated.modifiedAt > updated.createdAt)
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare repositories for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let repository1 = Repository(
            id: UUID(),
            name: "Test 1",
            path: URL(fileURLWithPath: "/test/1")
        )
        
        let repository2 = Repository(
            id: repository1.id,
            name: "Test 1",
            path: URL(fileURLWithPath: "/test/1")
        )
        
        let repository3 = Repository(
            id: UUID(),
            name: "Test 1",
            path: URL(fileURLWithPath: "/test/1")
        )
        
        #expect(repository1 == repository2)
        #expect(repository1 != repository3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode repository", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic repository
            Repository(
                id: UUID(),
                name: "Basic Repository",
                path: URL(fileURLWithPath: "/basic/path")
            ),
            // Repository with all properties
            Repository(
                id: UUID(),
                name: "Full Repository",
                path: URL(fileURLWithPath: "/full/path"),
                createdAt: Date(timeIntervalSinceNow: -3600),
                modifiedAt: Date(timeIntervalSinceNow: -1800),
                lastBackupAt: Date(timeIntervalSinceNow: -900),
                lastCheckAt: Date(timeIntervalSinceNow: -600),
                lastPruneAt: Date(timeIntervalSinceNow: -300),
                status: .ready
            ),
            // Repository with error status
            Repository(
                id: UUID(),
                name: "Error Repository",
                path: URL(fileURLWithPath: "/error/path"),
                status: .error("test error")
            )
        ]
        
        for repository in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(repository)
            let decoded = try decoder.decode(Repository.self, from: data)
            
            // Then
            #expect(decoded.id == repository.id)
            #expect(decoded.name == repository.name)
            #expect(decoded.path == repository.path)
            #expect(decoded.createdAt == repository.createdAt)
            #expect(decoded.modifiedAt == repository.modifiedAt)
            #expect(decoded.lastBackupAt == repository.lastBackupAt)
            #expect(decoded.lastCheckAt == repository.lastCheckAt)
            #expect(decoded.lastPruneAt == repository.lastPruneAt)
            #expect(decoded.status == repository.status)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate repository properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Empty name
            ("", URL(fileURLWithPath: "/test"), false),
            // Name with only spaces
            ("   ", URL(fileURLWithPath: "/test"), false),
            // Valid name
            ("Test Repository", URL(fileURLWithPath: "/test"), true),
            // Name with special characters
            ("Test!@#$%^&*()", URL(fileURLWithPath: "/test"), true),
            // Very long name
            (String(repeating: "a", count: 1000), URL(fileURLWithPath: "/test"), false),
            // Invalid path
            ("Test", URL(string: "invalid://path")!, false),
            // Valid path with spaces
            ("Test", URL(fileURLWithPath: "/test/path with spaces"), true),
            // Valid network path
            ("Test", URL(string: "sftp:user@host:/path")!, true)
        ]
        
        for (name, path, isValid) in testCases {
            let repository = Repository(
                id: UUID(),
                name: name,
                path: path
            )
            
            if isValid {
                #expect(repository.isValid)
            } else {
                #expect(!repository.isValid)
            }
        }
    }
}
