//
//  BackupMetadataTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupMetadataTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup metadata with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let repositoryId = UUID()
        let snapshotId = "2024-01-30-23-31-18"
        let timestamp = Date()
        let fileCount: UInt64 = 1000
        let totalSize: UInt64 = 1024 * 1024 * 1024 // 1 GB
        
        // When
        let metadata = BackupMetadata(
            repositoryId: repositoryId,
            snapshotId: snapshotId,
            timestamp: timestamp,
            fileCount: fileCount,
            totalSize: totalSize
        )
        
        // Then
        #expect(metadata.repositoryId == repositoryId)
        #expect(metadata.snapshotId == snapshotId)
        #expect(metadata.timestamp == timestamp)
        #expect(metadata.fileCount == fileCount)
        #expect(metadata.totalSize == totalSize)
        #expect(metadata.tags.isEmpty)
        #expect(metadata.excludedPaths.isEmpty)
        #expect(metadata.includedPaths.isEmpty)
    }
    
    @Test("Initialize backup metadata with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let repositoryId = UUID()
        let snapshotId = "2024-01-30-23-31-18"
        let timestamp = Date()
        let fileCount: UInt64 = 1000
        let totalSize: UInt64 = 1024 * 1024 * 1024 // 1 GB
        let tags = ["documents", "photos"]
        let excludedPaths = ["/Users/test/Downloads", "/Users/test/Library"]
        let includedPaths = ["/Users/test/Documents", "/Users/test/Pictures"]
        
        // When
        let metadata = BackupMetadata(
            repositoryId: repositoryId,
            snapshotId: snapshotId,
            timestamp: timestamp,
            fileCount: fileCount,
            totalSize: totalSize,
            tags: tags,
            excludedPaths: excludedPaths,
            includedPaths: includedPaths
        )
        
        // Then
        #expect(metadata.repositoryId == repositoryId)
        #expect(metadata.snapshotId == snapshotId)
        #expect(metadata.timestamp == timestamp)
        #expect(metadata.fileCount == fileCount)
        #expect(metadata.totalSize == totalSize)
        #expect(metadata.tags == tags)
        #expect(metadata.excludedPaths == excludedPaths)
        #expect(metadata.includedPaths == includedPaths)
    }
    
    // MARK: - Size Tests
    
    @Test("Handle metadata size formatting", tags: ["model", "size"])
    func testSizeFormatting() throws {
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
            let metadata = BackupMetadata(
                repositoryId: UUID(),
                snapshotId: "test",
                timestamp: Date(),
                fileCount: 1,
                totalSize: size
            )
            
            #expect(metadata.formattedTotalSize == formattedSize)
        }
    }
    
    // MARK: - Tag Tests
    
    @Test("Handle metadata tags", tags: ["model", "tags"])
    func testTags() throws {
        let testCases = [
            // Valid tags
            ["documents", "photos"],
            ["system", "critical", "monthly"],
            // Empty tags
            [],
            // Invalid tags
            ["", " ", "invalid tag"],
            [String(repeating: "a", count: 1000)]
        ]
        
        for tags in testCases {
            let metadata = BackupMetadata(
                repositoryId: UUID(),
                snapshotId: "test",
                timestamp: Date(),
                fileCount: 1,
                totalSize: 0,
                tags: tags
            )
            
            let isValid = tags.allSatisfy { tag in
                !tag.isEmpty &&
                !tag.contains(" ") &&
                tag.count <= 100
            }
            
            if isValid {
                #expect(metadata.isValid)
                #expect(metadata.tags == tags)
            } else {
                #expect(!metadata.isValid)
            }
        }
    }
    
    // MARK: - Path Tests
    
    @Test("Handle metadata paths", tags: ["model", "paths"])
    func testPaths() throws {
        let testCases = [
            // Valid paths
            (["/Users/test/Documents"], ["/Users/test/Downloads"]),
            (["/Applications", "/Library"], ["/System/Volumes/Data"]),
            // Empty paths
            ([], []),
            // Paths with spaces
            (["/Users/test/My Documents"], ["/Volumes/Backup Drive"]),
            // Invalid paths
            ([""], [" "]),
            (["relative/path"], ["no-leading-slash"])
        ]
        
        for (includedPaths, excludedPaths) in testCases {
            let metadata = BackupMetadata(
                repositoryId: UUID(),
                snapshotId: "test",
                timestamp: Date(),
                fileCount: 1,
                totalSize: 0,
                excludedPaths: excludedPaths,
                includedPaths: includedPaths
            )
            
            let isValid = (includedPaths.isEmpty || includedPaths.allSatisfy { $0.hasPrefix("/") }) &&
                         (excludedPaths.isEmpty || excludedPaths.allSatisfy { $0.hasPrefix("/") })
            
            if isValid {
                #expect(metadata.isValid)
                #expect(metadata.includedPaths == includedPaths)
                #expect(metadata.excludedPaths == excludedPaths)
            } else {
                #expect(!metadata.isValid)
            }
        }
    }
    
    // MARK: - File Count Tests
    
    @Test("Handle file count formatting", tags: ["model", "files"])
    func testFileCountFormatting() throws {
        let testCases: [(UInt64, String)] = [
            (0, "0 files"),
            (1, "1 file"),
            (2, "2 files"),
            (1000, "1,000 files"),
            (1000000, "1,000,000 files"),
            (UInt64.max, String(format: "%d files", UInt64.max))
        ]
        
        for (count, formattedCount) in testCases {
            let metadata = BackupMetadata(
                repositoryId: UUID(),
                snapshotId: "test",
                timestamp: Date(),
                fileCount: count,
                totalSize: 0
            )
            
            #expect(metadata.formattedFileCount == formattedCount)
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup metadata for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let repositoryId = UUID()
        let timestamp = Date()
        
        let metadata1 = BackupMetadata(
            repositoryId: repositoryId,
            snapshotId: "test1",
            timestamp: timestamp,
            fileCount: 1000,
            totalSize: 1024 * 1024,
            tags: ["documents"],
            excludedPaths: ["/test/excluded"],
            includedPaths: ["/test/included"]
        )
        
        let metadata2 = BackupMetadata(
            repositoryId: repositoryId,
            snapshotId: "test1",
            timestamp: timestamp,
            fileCount: 1000,
            totalSize: 1024 * 1024,
            tags: ["documents"],
            excludedPaths: ["/test/excluded"],
            includedPaths: ["/test/included"]
        )
        
        let metadata3 = BackupMetadata(
            repositoryId: repositoryId,
            snapshotId: "test2",
            timestamp: timestamp,
            fileCount: 1000,
            totalSize: 1024 * 1024,
            tags: ["documents"],
            excludedPaths: ["/test/excluded"],
            includedPaths: ["/test/included"]
        )
        
        #expect(metadata1 == metadata2)
        #expect(metadata1 != metadata3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup metadata", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic metadata
            BackupMetadata(
                repositoryId: UUID(),
                snapshotId: "basic",
                timestamp: Date(),
                fileCount: 1000,
                totalSize: 1024 * 1024
            ),
            // Metadata with tags
            BackupMetadata(
                repositoryId: UUID(),
                snapshotId: "with-tags",
                timestamp: Date(),
                fileCount: 1000,
                totalSize: 1024 * 1024,
                tags: ["documents", "photos"]
            ),
            // Full metadata
            BackupMetadata(
                repositoryId: UUID(),
                snapshotId: "full",
                timestamp: Date(),
                fileCount: 1000,
                totalSize: 1024 * 1024,
                tags: ["documents", "photos"],
                excludedPaths: ["/test/excluded"],
                includedPaths: ["/test/included"]
            )
        ]
        
        for metadata in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(metadata)
            let decoded = try decoder.decode(BackupMetadata.self, from: data)
            
            // Then
            #expect(decoded.repositoryId == metadata.repositoryId)
            #expect(decoded.snapshotId == metadata.snapshotId)
            #expect(decoded.timestamp == metadata.timestamp)
            #expect(decoded.fileCount == metadata.fileCount)
            #expect(decoded.totalSize == metadata.totalSize)
            #expect(decoded.tags == metadata.tags)
            #expect(decoded.excludedPaths == metadata.excludedPaths)
            #expect(decoded.includedPaths == metadata.includedPaths)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup metadata properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid metadata
            (UUID(), "valid-id", 1000, ["valid"], ["/valid"], ["/valid"], true),
            // Empty snapshot ID
            (UUID(), "", 1000, ["valid"], ["/valid"], ["/valid"], false),
            // Invalid tags
            (UUID(), "valid-id", 1000, ["invalid tag"], ["/valid"], ["/valid"], false),
            // Invalid paths
            (UUID(), "valid-id", 1000, ["valid"], ["invalid"], ["invalid"], false),
            // Zero file count
            (UUID(), "valid-id", 0, ["valid"], ["/valid"], ["/valid"], true)
        ]
        
        for (repositoryId, snapshotId, fileCount, tags, excludedPaths, includedPaths, isValid) in testCases {
            let metadata = BackupMetadata(
                repositoryId: repositoryId,
                snapshotId: snapshotId,
                timestamp: Date(),
                fileCount: fileCount,
                totalSize: 1024,
                tags: tags,
                excludedPaths: excludedPaths,
                includedPaths: includedPaths
            )
            
            if isValid {
                #expect(metadata.isValid)
            } else {
                #expect(!metadata.isValid)
            }
        }
    }
}
