//
//  BackupHistoryTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupHistory functionality
struct BackupHistoryTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let fileManager: MockFileManager
        let dateProvider: MockDateProvider
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.fileManager = MockFileManager()
            self.dateProvider = MockDateProvider()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            fileManager.reset()
            dateProvider.reset()
        }
        
        /// Create test history entry
        func createHistoryEntry(
            id: String = MockData.History.validId,
            timestamp: Date = MockData.History.validTimestamp,
            status: BackupStatus = .completed,
            repository: Repository = MockData.Repository.validRepository,
            snapshot: BackupSnapshot = MockData.Snapshot.validSnapshot,
            duration: TimeInterval = 300,
            bytesProcessed: UInt64 = 1024 * 1024,
            filesProcessed: UInt = 100
        ) -> BackupHistoryEntry {
            BackupHistoryEntry(
                id: id,
                timestamp: timestamp,
                status: status,
                repository: repository,
                snapshot: snapshot,
                duration: duration,
                bytesProcessed: bytesProcessed,
                filesProcessed: filesProcessed
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize with default values", tags: ["init", "history"])
    func testDefaultInitialization() throws {
        // Given: Default history parameters
        let context = TestContext()
        
        // When: Creating history entry
        let entry = context.createHistoryEntry()
        
        // Then: Entry is configured correctly
        #expect(entry.id == MockData.History.validId)
        #expect(entry.timestamp == MockData.History.validTimestamp)
        #expect(entry.status == .completed)
        #expect(entry.repository == MockData.Repository.validRepository)
        #expect(entry.snapshot == MockData.Snapshot.validSnapshot)
        #expect(entry.duration == 300)
        #expect(entry.bytesProcessed == 1024 * 1024)
        #expect(entry.filesProcessed == 100)
    }
    
    @Test("Initialize with custom values", tags: ["init", "history"])
    func testCustomInitialization() throws {
        // Given: Custom history parameters
        let context = TestContext()
        let customId = "custom-id"
        let customTimestamp = Date()
        let customRepository = MockData.Repository.customRepository
        let customSnapshot = MockData.Snapshot.customSnapshot
        
        // When: Creating history entry
        let entry = context.createHistoryEntry(
            id: customId,
            timestamp: customTimestamp,
            status: .failed,
            repository: customRepository,
            snapshot: customSnapshot,
            duration: 600,
            bytesProcessed: 2048 * 1024,
            filesProcessed: 200
        )
        
        // Then: Entry is configured correctly
        #expect(entry.id == customId)
        #expect(entry.timestamp == customTimestamp)
        #expect(entry.status == .failed)
        #expect(entry.repository == customRepository)
        #expect(entry.snapshot == customSnapshot)
        #expect(entry.duration == 600)
        #expect(entry.bytesProcessed == 2048 * 1024)
        #expect(entry.filesProcessed == 200)
    }
    
    // MARK: - Persistence Tests
    
    @Test("Save and load history", tags: ["persistence", "history"])
    func testPersistence() throws {
        // Given: History entry with custom values
        let context = TestContext()
        let entry = context.createHistoryEntry(
            id: "test-id",
            status: .failed,
            duration: 600,
            bytesProcessed: 2048 * 1024,
            filesProcessed: 200
        )
        
        // When: Saving and loading history
        entry.save(to: context.userDefaults)
        let loaded = BackupHistoryEntry.load(from: context.userDefaults, withId: entry.id)
        
        // Then: Loaded entry matches original
        #expect(loaded?.id == entry.id)
        #expect(loaded?.timestamp == entry.timestamp)
        #expect(loaded?.status == entry.status)
        #expect(loaded?.repository == entry.repository)
        #expect(loaded?.snapshot == entry.snapshot)
        #expect(loaded?.duration == entry.duration)
        #expect(loaded?.bytesProcessed == entry.bytesProcessed)
        #expect(loaded?.filesProcessed == entry.filesProcessed)
    }
    
    // MARK: - Status Tests
    
    @Test("Handle backup status", tags: ["status", "history"])
    func testStatus() throws {
        // Given: History entries with different statuses
        let context = TestContext()
        let testCases: [(BackupStatus, String)] = [
            (.completed, "Completed"),
            (.failed, "Failed"),
            (.inProgress, "In Progress"),
            (.cancelled, "Cancelled"),
            (.scheduled, "Scheduled")
        ]
        
        // When/Then: Test status handling
        for (status, description) in testCases {
            let entry = context.createHistoryEntry(status: status)
            #expect(entry.status == status)
            #expect(entry.statusDescription == description)
        }
    }
    
    // MARK: - Formatting Tests
    
    @Test("Format history values", tags: ["formatting", "history"])
    func testFormatting() throws {
        // Given: History entry with values to format
        let context = TestContext()
        let entry = context.createHistoryEntry(
            duration: 3665, // 1 hour, 1 minute, 5 seconds
            bytesProcessed: 1536 * 1024, // 1.5 MB
            filesProcessed: 1234
        )
        
        // Then: Values are formatted correctly
        #expect(entry.formattedDuration == "1h 1m 5s")
        #expect(entry.formattedBytesProcessed == "1.5 MB")
        #expect(entry.formattedFilesProcessed == "1,234 files")
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle edge cases", tags: ["edge", "history"])
    func testEdgeCases() throws {
        // Given: Edge case scenarios
        let context = TestContext()
        
        // Test nil UserDefaults
        let nilDefaults = MockUserDefaults()
        nilDefaults.removeObject(forKey: BackupHistoryEntry.defaultsKey)
        let loadedEntry = BackupHistoryEntry.load(from: nilDefaults, withId: "test-id")
        #expect(loadedEntry == nil)
        
        // Test zero values
        let zeroEntry = context.createHistoryEntry(
            duration: 0,
            bytesProcessed: 0,
            filesProcessed: 0
        )
        #expect(zeroEntry.formattedDuration == "0s")
        #expect(zeroEntry.formattedBytesProcessed == "0 B")
        #expect(zeroEntry.formattedFilesProcessed == "0 files")
        
        // Test maximum values
        let maxEntry = context.createHistoryEntry(
            duration: TimeInterval.greatestFiniteMagnitude,
            bytesProcessed: UInt64.max,
            filesProcessed: UInt.max
        )
        #expect(!maxEntry.formattedDuration.isEmpty)
        #expect(!maxEntry.formattedBytesProcessed.isEmpty)
        #expect(!maxEntry.formattedFilesProcessed.isEmpty)
    }
}

// MARK: - Mock Implementations

/// Mock implementation of UserDefaults for testing
final class MockUserDefaults: UserDefaults {
    var storage: [String: Any] = [:]
    
    override func set(_ value: Any?, forKey defaultName: String) {
        if let value = value {
            storage[defaultName] = value
        } else {
            storage.removeValue(forKey: defaultName)
        }
    }
    
    override func object(forKey defaultName: String) -> Any? {
        storage[defaultName]
    }
    
    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
    
    func reset() {
        storage.removeAll()
    }
}

/// Mock implementation of FileManager for testing
final class MockFileManager: FileManager {
    var files: [String: Bool] = [:]
    
    override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        files[path] ?? false
    }
    
    func addFile(_ path: String) {
        files[path] = true
    }
    
    func reset() {
        files.removeAll()
    }
}

/// Mock implementation of DateProvider for testing
final class MockDateProvider: DateProvider {
    var currentDate: Date = Date()
    
    func now() -> Date {
        currentDate
    }
    
    func setDate(_ date: Date) {
        currentDate = date
    }
    
    func reset() {
        currentDate = Date()
    }
}
