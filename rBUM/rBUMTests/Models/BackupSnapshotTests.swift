//
//  BackupSnapshotTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupSnapshotTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup snapshot with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = "2024-01-30-23-28-08"
        let repositoryId = UUID()
        let timestamp = Date()
        let size: UInt64 = 1024 * 1024 // 1 MB
        
        // When
        let snapshot = BackupSnapshot(
            id: id,
            repositoryId: repositoryId,
            timestamp: timestamp,
            size: size
        )
        
        // Then
        #expect(snapshot.id == id)
        #expect(snapshot.repositoryId == repositoryId)
        #expect(snapshot.timestamp == timestamp)
        #expect(snapshot.size == size)
        #expect(snapshot.tags.isEmpty)
        #expect(snapshot.hostname == Host.current().localizedName)
        #expect(snapshot.username == NSUserName())
        #expect(snapshot.paths.isEmpty)
    }
    
    @Test("Initialize backup snapshot with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = "2024-01-30-23-28-08"
        let repositoryId = UUID()
        let timestamp = Date()
        let size: UInt64 = 1024 * 1024 // 1 MB
        let tags = ["daily", "documents"]
        let hostname = "test-host"
        let username = "testuser"
        let paths = ["/Users/test/Documents", "/Users/test/Pictures"]
        
        // When
        let snapshot = BackupSnapshot(
            id: id,
            repositoryId: repositoryId,
            timestamp: timestamp,
            size: size,
            tags: tags,
            hostname: hostname,
            username: username,
            paths: paths
        )
        
        // Then
        #expect(snapshot.id == id)
        #expect(snapshot.repositoryId == repositoryId)
        #expect(snapshot.timestamp == timestamp)
        #expect(snapshot.size == size)
        #expect(snapshot.tags == tags)
        #expect(snapshot.hostname == hostname)
        #expect(snapshot.username == username)
        #expect(snapshot.paths == paths)
    }
    
    // MARK: - ID Tests
    
    @Test("Handle snapshot ID formats", tags: ["model", "id"])
    func testIdFormats() throws {
        let testCases = [
            // Valid IDs
            "2024-01-30-23-28-08",
            "2024-01-30T23:28:08Z",
            "20240130232808",
            // Invalid IDs
            "",
            " ",
            "invalid",
            "2024-13-45-99-99-99",
            String(repeating: "a", count: 1000)
        ]
        
        for id in testCases {
            let snapshot = BackupSnapshot(
                id: id,
                repositoryId: UUID(),
                timestamp: Date(),
                size: 0
            )
            
            let isValid = !id.isEmpty &&
                         id.trimmingCharacters(in: .whitespaces) == id &&
                         id.count <= 100
            
            if isValid {
                #expect(snapshot.isValid)
                #expect(snapshot.id == id)
            } else {
                #expect(!snapshot.isValid)
            }
        }
    }
    
    // MARK: - Size Tests
    
    @Test("Handle snapshot sizes", tags: ["model", "size"])
    func testSizes() throws {
        let testCases: [(UInt64, String)] = [
            // Bytes
            (500, "500 B"),
            // Kilobytes
            (1024, "1.0 KB"),
            (1536, "1.5 KB"),
            // Megabytes
            (1024 * 1024, "1.0 MB"),
            (1024 * 1024 * 1.5, "1.5 MB"),
            // Gigabytes
            (1024 * 1024 * 1024, "1.0 GB"),
            (1024 * 1024 * 1024 * 2.5, "2.5 GB"),
            // Terabytes
            (1024 * 1024 * 1024 * 1024, "1.0 TB")
        ]
        
        for (size, formattedSize) in testCases {
            let snapshot = BackupSnapshot(
                id: "test",
                repositoryId: UUID(),
                timestamp: Date(),
                size: size
            )
            
            #expect(snapshot.size == size)
            #expect(snapshot.formattedSize == formattedSize)
        }
    }
    
    // MARK: - Tag Tests
    
    @Test("Handle snapshot tags", tags: ["model", "tags"])
    func testTags() throws {
        let testCases = [
            // Valid tags
            ["daily", "documents"],
            ["weekly", "system", "critical"],
            // Empty tags
            [],
            // Invalid tags
            ["", " ", "invalid tag"],
            [String(repeating: "a", count: 1000)]
        ]
        
        for tags in testCases {
            let snapshot = BackupSnapshot(
                id: "test",
                repositoryId: UUID(),
                timestamp: Date(),
                size: 0,
                tags: tags
            )
            
            let isValid = tags.allSatisfy { tag in
                !tag.isEmpty &&
                !tag.contains(" ") &&
                tag.count <= 100
            }
            
            if isValid {
                #expect(snapshot.isValid)
                #expect(snapshot.tags == tags)
            } else {
                #expect(!snapshot.isValid)
            }
        }
    }
    
    // MARK: - Path Tests
    
    @Test("Handle snapshot paths", tags: ["model", "paths"])
    func testPaths() throws {
        let testCases = [
            // Valid paths
            ["/Users/test/Documents", "/Users/test/Pictures"],
            ["/Applications", "/Library/Preferences"],
            // Empty paths
            [],
            // Paths with spaces
            ["/Users/test/My Documents", "/Volumes/Backup Drive/Data"],
            // Paths with special characters
            ["/Users/test/Documents!@#$%", "/Test/Path/With/Symbols/*&^"],
            // Very long paths
            ["/Users/test/" + String(repeating: "a", count: 1000)]
        ]
        
        for paths in testCases {
            let snapshot = BackupSnapshot(
                id: "test",
                repositoryId: UUID(),
                timestamp: Date(),
                size: 0,
                paths: paths
            )
            
            let isValid = paths.allSatisfy { path in
                !path.isEmpty && path.hasPrefix("/")
            }
            
            if isValid {
                #expect(snapshot.isValid)
                #expect(snapshot.paths == paths)
            } else {
                #expect(!snapshot.isValid)
            }
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup snapshots for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let repositoryId = UUID()
        let timestamp = Date()
        
        let snapshot1 = BackupSnapshot(
            id: "test1",
            repositoryId: repositoryId,
            timestamp: timestamp,
            size: 1024,
            tags: ["daily"],
            paths: ["/test"]
        )
        
        let snapshot2 = BackupSnapshot(
            id: "test1",
            repositoryId: repositoryId,
            timestamp: timestamp,
            size: 1024,
            tags: ["daily"],
            paths: ["/test"]
        )
        
        let snapshot3 = BackupSnapshot(
            id: "test2",
            repositoryId: repositoryId,
            timestamp: timestamp,
            size: 1024,
            tags: ["daily"],
            paths: ["/test"]
        )
        
        #expect(snapshot1 == snapshot2)
        #expect(snapshot1 != snapshot3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup snapshot", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic snapshot
            BackupSnapshot(
                id: "basic",
                repositoryId: UUID(),
                timestamp: Date(),
                size: 1024
            ),
            // Snapshot with tags
            BackupSnapshot(
                id: "with-tags",
                repositoryId: UUID(),
                timestamp: Date(),
                size: 1024,
                tags: ["daily", "documents"]
            ),
            // Full snapshot
            BackupSnapshot(
                id: "full",
                repositoryId: UUID(),
                timestamp: Date(),
                size: 1024 * 1024,
                tags: ["weekly", "system"],
                hostname: "test-host",
                username: "testuser",
                paths: ["/test/path1", "/test/path2"]
            )
        ]
        
        for snapshot in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(snapshot)
            let decoded = try decoder.decode(BackupSnapshot.self, from: data)
            
            // Then
            #expect(decoded.id == snapshot.id)
            #expect(decoded.repositoryId == snapshot.repositoryId)
            #expect(decoded.timestamp == snapshot.timestamp)
            #expect(decoded.size == snapshot.size)
            #expect(decoded.tags == snapshot.tags)
            #expect(decoded.hostname == snapshot.hostname)
            #expect(decoded.username == snapshot.username)
            #expect(decoded.paths == snapshot.paths)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup snapshot properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid snapshot
            ("valid-id", UUID(), 1024, ["daily"], ["/test"], true),
            // Empty ID
            ("", UUID(), 1024, ["daily"], ["/test"], false),
            // Invalid tags
            ("valid-id", UUID(), 1024, ["invalid tag"], ["/test"], false),
            // Invalid paths
            ("valid-id", UUID(), 1024, ["daily"], ["invalid-path"], false),
            // Zero size
            ("valid-id", UUID(), 0, ["daily"], ["/test"], true)
        ]
        
        for (id, repositoryId, size, tags, paths, isValid) in testCases {
            let snapshot = BackupSnapshot(
                id: id,
                repositoryId: repositoryId,
                timestamp: Date(),
                size: size,
                tags: tags,
                paths: paths
            )
            
            if isValid {
                #expect(snapshot.isValid)
            } else {
                #expect(!snapshot.isValid)
            }
        }
    }
}
