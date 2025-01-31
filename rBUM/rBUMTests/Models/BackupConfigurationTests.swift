//
//  BackupConfigurationTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupConfigurationTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup configuration with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let name = "Test Backup"
        let sourcePath = URL(fileURLWithPath: "/test/source")
        let repositoryId = UUID()
        
        // When
        let config = BackupConfiguration(
            id: id,
            name: name,
            sourcePath: sourcePath,
            repositoryId: repositoryId
        )
        
        // Then
        #expect(config.id == id)
        #expect(config.name == name)
        #expect(config.sourcePath == sourcePath)
        #expect(config.repositoryId == repositoryId)
        #expect(config.excludePatterns.isEmpty)
        #expect(config.schedule == nil)
        #expect(config.createdAt.timeIntervalSinceNow <= 0)
        #expect(config.modifiedAt.timeIntervalSinceNow <= 0)
    }
    
    @Test("Initialize backup configuration with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let name = "Test Backup"
        let sourcePath = URL(fileURLWithPath: "/test/source")
        let repositoryId = UUID()
        let excludePatterns = ["*.log", "tmp/*"]
        let schedule = BackupSchedule(interval: .daily, time: Date())
        
        // When
        let config = BackupConfiguration(
            id: id,
            name: name,
            sourcePath: sourcePath,
            repositoryId: repositoryId,
            excludePatterns: excludePatterns,
            schedule: schedule
        )
        
        // Then
        #expect(config.id == id)
        #expect(config.name == name)
        #expect(config.sourcePath == sourcePath)
        #expect(config.repositoryId == repositoryId)
        #expect(config.excludePatterns == excludePatterns)
        #expect(config.schedule == schedule)
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare configurations for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        // Given
        let id = UUID()
        let name = "Test Backup"
        let sourcePath = URL(fileURLWithPath: "/test/source")
        let repositoryId = UUID()
        let excludePatterns = ["*.log"]
        let schedule = BackupSchedule(interval: .daily, time: Date())
        
        let config1 = BackupConfiguration(
            id: id,
            name: name,
            sourcePath: sourcePath,
            repositoryId: repositoryId,
            excludePatterns: excludePatterns,
            schedule: schedule
        )
        
        let config2 = BackupConfiguration(
            id: id,
            name: name,
            sourcePath: sourcePath,
            repositoryId: repositoryId,
            excludePatterns: excludePatterns,
            schedule: schedule
        )
        
        let config3 = BackupConfiguration(
            id: UUID(),
            name: name,
            sourcePath: sourcePath,
            repositoryId: repositoryId,
            excludePatterns: excludePatterns,
            schedule: schedule
        )
        
        // Then
        #expect(config1 == config2)
        #expect(config1 != config3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode configuration", tags: ["model", "serialization"])
    func testCodable() throws {
        // Given
        let id = UUID()
        let name = "Test Backup"
        let sourcePath = URL(fileURLWithPath: "/test/source")
        let repositoryId = UUID()
        let excludePatterns = ["*.log", "tmp/*"]
        let schedule = BackupSchedule(interval: .daily, time: Date())
        
        let config = BackupConfiguration(
            id: id,
            name: name,
            sourcePath: sourcePath,
            repositoryId: repositoryId,
            excludePatterns: excludePatterns,
            schedule: schedule
        )
        
        // When
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(BackupConfiguration.self, from: data)
        
        // Then
        #expect(decoded.id == config.id)
        #expect(decoded.name == config.name)
        #expect(decoded.sourcePath == config.sourcePath)
        #expect(decoded.repositoryId == config.repositoryId)
        #expect(decoded.excludePatterns == config.excludePatterns)
        #expect(decoded.schedule == config.schedule)
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate source paths", tags: ["model", "validation"])
    func testSourcePathValidation() throws {
        let invalidPaths = [
            "", // Empty path
            "relative/path", // Relative path
            "/path/with/null/\0/character", // Path with null character
            "/path/with/newline\n/character", // Path with newline
            String(repeating: "a", count: 4096) // Extremely long path
        ]
        
        for path in invalidPaths {
            // Attempt to create configuration with invalid path
            let config = BackupConfiguration(
                id: UUID(),
                name: "Test",
                sourcePath: URL(fileURLWithPath: path),
                repositoryId: UUID()
            )
            
            // Verify path is normalized
            let normalizedPath = config.sourcePath.path
            #expect(!normalizedPath.contains("\0"))
            #expect(!normalizedPath.contains("\n"))
            #expect(normalizedPath.count <= 1024)
            #expect(normalizedPath.hasPrefix("/"))
        }
    }
    
    @Test("Validate exclude patterns", tags: ["model", "validation"])
    func testExcludePatternValidation() throws {
        let testCases = [
            // Basic patterns
            ["*.log", "tmp/*", ".DS_Store"],
            ["node_modules/", "*.tmp", "*.bak"],
            // Empty patterns
            [""],
            // Patterns with spaces
            ["file with spaces.txt", "folder with spaces/*"],
            // Special characters
            ["test!@#$%^&*()_+.txt", "[abc].txt", "{test}.log"],
            // Very long patterns
            [String(repeating: "a", count: 1000)],
            // Multiple patterns with mixed formats
            ["*.log", "test[0-9].txt", "backup{1,2,3}.dat", "**/*.tmp"]
        ]
        
        for patterns in testCases {
            // Create configuration with test patterns
            let config = BackupConfiguration(
                id: UUID(),
                name: "Test",
                sourcePath: URL(fileURLWithPath: "/test"),
                repositoryId: UUID(),
                excludePatterns: patterns
            )
            
            // Verify patterns are preserved
            #expect(config.excludePatterns == patterns)
        }
    }
    
    // MARK: - Schedule Tests
    
    @Test("Handle backup schedules", tags: ["model", "schedule"])
    func testScheduleHandling() throws {
        let testCases = [
            // Daily schedule
            BackupSchedule(interval: .daily, time: Date()),
            // Weekly schedule
            BackupSchedule(interval: .weekly, time: Date()),
            // Monthly schedule
            BackupSchedule(interval: .monthly, time: Date()),
            // Custom interval schedule
            BackupSchedule(interval: .custom(hours: 12), time: Date())
        ]
        
        for schedule in testCases {
            // Create configuration with schedule
            let config = BackupConfiguration(
                id: UUID(),
                name: "Test",
                sourcePath: URL(fileURLWithPath: "/test"),
                repositoryId: UUID(),
                schedule: schedule
            )
            
            // Verify schedule is preserved
            #expect(config.schedule == schedule)
            
            // Test serialization of schedule
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(config)
            let decoded = try decoder.decode(BackupConfiguration.self, from: data)
            
            #expect(decoded.schedule == schedule)
        }
    }
    
    @Test("Handle timestamp behavior", tags: ["model", "timestamp"])
    func testTimestampBehavior() throws {
        // Given initial configuration
        let config = BackupConfiguration(
            id: UUID(),
            name: "Test",
            sourcePath: URL(fileURLWithPath: "/test"),
            repositoryId: UUID()
        )
        
        // Initial timestamps should be close to now
        let now = Date()
        #expect(abs(config.createdAt.timeIntervalSince(now)) < 1.0)
        #expect(abs(config.modifiedAt.timeIntervalSince(now)) < 1.0)
        #expect(config.createdAt == config.modifiedAt)
        
        // Sleep to ensure time difference
        Thread.sleep(forTimeInterval: 0.1)
        
        // When updating
        var updated = config
        updated.name = "Updated Test"
        
        // Then timestamps should reflect the change
        #expect(updated.createdAt == config.createdAt)
        #expect(updated.modifiedAt > config.modifiedAt)
        #expect(updated.modifiedAt > updated.createdAt)
    }
    
    // MARK: - Pattern Tests
    
    @Test("Handle exclude pattern validation", tags: ["model", "patterns"])
    func testExcludePatterns() throws {
        let testCases = [
            // Valid patterns
            ["*.log", "tmp/*", ".DS_Store"],
            ["node_modules/", "*.tmp", "*.bak"],
            // Empty patterns
            [],
            // Invalid patterns
            [""], // Empty pattern
            [" "], // Whitespace only
            [String(repeating: "*", count: 1000)] // Too long
        ]
        
        for patterns in testCases {
            let config = BackupConfiguration(
                id: UUID(),
                name: "Test",
                sourcePath: URL(fileURLWithPath: "/test"),
                repositoryId: UUID(),
                excludePatterns: patterns
            )
            
            let isValid = patterns.allSatisfy { pattern in
                !pattern.isEmpty &&
                pattern.trimmingCharacters(in: .whitespaces) == pattern &&
                pattern.count <= 100
            }
            
            if isValid {
                #expect(config.isValid)
                #expect(config.excludePatterns == patterns)
            } else {
                #expect(!config.isValid)
            }
        }
    }
    
    // MARK: - Name Tests
    
    @Test("Handle configuration name validation", tags: ["model", "name"])
    func testNameValidation() throws {
        let testCases = [
            // Valid names
            "Daily Backup",
            "System Files",
            "Photos - 2024",
            // Invalid names
            "",
            " ",
            String(repeating: "a", count: 1000)
        ]
        
        for name in testCases {
            let config = BackupConfiguration(
                id: UUID(),
                name: name,
                sourcePath: URL(fileURLWithPath: "/test"),
                repositoryId: UUID()
            )
            
            let isValid = !name.isEmpty &&
                         name.trimmingCharacters(in: .whitespaces) == name &&
                         name.count <= 100
            
            if isValid {
                #expect(config.isValid)
                #expect(config.name == name)
            } else {
                #expect(!config.isValid)
            }
        }
    }
    
    // MARK: - Schedule Tests
    
    @Test("Handle schedule updates", tags: ["model", "schedule"])
    func testScheduleUpdates() throws {
        // Given
        var config = BackupConfiguration(
            id: UUID(),
            name: "Test",
            sourcePath: URL(fileURLWithPath: "/test"),
            repositoryId: UUID()
        )
        
        let testCases = [
            // Daily schedule
            BackupSchedule(interval: .daily, time: Date()),
            // Weekly schedule
            BackupSchedule(
                interval: .weekly,
                time: Date(),
                weeklyDays: [.monday, .wednesday, .friday]
            ),
            // Monthly schedule
            BackupSchedule(
                interval: .monthly,
                time: Date(),
                monthlyDays: [1, 15]
            ),
            // Custom schedule
            BackupSchedule(interval: .custom(hours: 12), time: Date()),
            // No schedule
            nil
        ]
        
        for schedule in testCases {
            // When
            config.schedule = schedule
            
            // Then
            #expect(config.schedule == schedule)
            if schedule != nil {
                #expect(config.modifiedAt > config.createdAt)
            }
        }
    }
    
    // MARK: - Timestamp Tests
    
    @Test("Handle timestamp updates", tags: ["model", "timestamp"])
    func testTimestampUpdates() throws {
        // Given
        var config = BackupConfiguration(
            id: UUID(),
            name: "Test",
            sourcePath: URL(fileURLWithPath: "/test"),
            repositoryId: UUID()
        )
        
        let originalCreatedAt = config.createdAt
        let originalModifiedAt = config.modifiedAt
        
        // Test property updates
        let testUpdates = [
            { config.name = "Updated Name" },
            { config.sourcePath = URL(fileURLWithPath: "/updated") },
            { config.excludePatterns = ["*.new"] },
            { config.schedule = BackupSchedule(interval: .daily, time: Date()) }
        ]
        
        for update in testUpdates {
            // When
            update()
            
            // Then
            #expect(config.createdAt == originalCreatedAt)
            #expect(config.modifiedAt > originalModifiedAt)
        }
    }
    
    // MARK: - Description Tests
    
    @Test("Generate human-readable configuration descriptions", tags: ["model", "description"])
    func testDescriptions() throws {
        let testCases = [
            // Basic configuration
            (
                BackupConfiguration(
                    id: UUID(),
                    name: "Daily Backup",
                    sourcePath: URL(fileURLWithPath: "/test"),
                    repositoryId: UUID()
                ),
                "Daily Backup (/test)"
            ),
            // Configuration with schedule
            (
                BackupConfiguration(
                    id: UUID(),
                    name: "Weekly Backup",
                    sourcePath: URL(fileURLWithPath: "/data"),
                    repositoryId: UUID(),
                    schedule: BackupSchedule(interval: .weekly, time: Date())
                ),
                "Weekly Backup (/data) - Weekly"
            ),
            // Configuration with patterns
            (
                BackupConfiguration(
                    id: UUID(),
                    name: "System Backup",
                    sourcePath: URL(fileURLWithPath: "/system"),
                    repositoryId: UUID(),
                    excludePatterns: ["*.log", "tmp/*"]
                ),
                "System Backup (/system) - 2 exclusions"
            )
        ]
        
        for (config, expectedDescription) in testCases {
            #expect(config.description == expectedDescription)
        }
    }
}
