import Testing
@testable import rBUM

/// Tests for BackupLog functionality
struct BackupLogTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let fileManager: MockFileManager
        let dateProvider: MockDateProvider
        let notificationCenter: MockNotificationCenter
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.fileManager = MockFileManager()
            self.dateProvider = MockDateProvider()
            self.notificationCenter = MockNotificationCenter()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            fileManager.reset()
            dateProvider.reset()
            notificationCenter.reset()
        }
        
        /// Create test log
        func createLog() -> BackupLog {
            BackupLog(
                userDefaults: userDefaults,
                fileManager: fileManager,
                dateProvider: dateProvider,
                notificationCenter: notificationCenter
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup log", tags: ["init", "log"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating log
        let log = context.createLog()
        
        // Then: Log is configured correctly
        #expect(log.entries.isEmpty)
        #expect(log.isEnabled)
        #expect(log.maxEntries == BackupLog.defaultMaxEntries)
    }
    
    // MARK: - Entry Management Tests
    
    @Test("Test log entry management", tags: ["entry", "log"])
    func testEntryManagement() throws {
        // Given: Log and test data
        let context = TestContext()
        let log = context.createLog()
        
        let entry = MockData.Log.validEntry
        
        // When: Adding entry
        log.add(entry)
        
        // Then: Entry is stored
        #expect(log.entries.count == 1)
        #expect(log.entries.first == entry)
        #expect(context.notificationCenter.postCalled)
        
        // When: Clearing entries
        log.clear()
        
        // Then: Entries are removed
        #expect(log.entries.isEmpty)
    }
    
    // MARK: - Entry Rotation Tests
    
    @Test("Test log entry rotation", tags: ["rotation", "log"])
    func testEntryRotation() throws {
        // Given: Log with max entries
        let context = TestContext()
        let log = context.createLog()
        log.maxEntries = 2
        
        let entries = [
            MockData.Log.validEntry,
            MockData.Log.customEntry,
            MockData.Log.errorEntry
        ]
        
        // When: Adding more entries than max
        for entry in entries {
            log.add(entry)
        }
        
        // Then: Oldest entries are removed
        #expect(log.entries.count == 2)
        #expect(log.entries.contains(entries[1]))
        #expect(log.entries.contains(entries[2]))
        #expect(!log.entries.contains(entries[0]))
    }
    
    // MARK: - Entry Filtering Tests
    
    @Test("Test log entry filtering", tags: ["filter", "log"])
    func testEntryFiltering() throws {
        // Given: Log with various entries
        let context = TestContext()
        let log = context.createLog()
        
        let entries = [
            MockData.Log.validEntry,
            MockData.Log.errorEntry,
            MockData.Log.customEntry
        ]
        
        for entry in entries {
            log.add(entry)
        }
        
        // Test filtering by level
        let errorEntries = log.entries(withLevel: .error)
        #expect(errorEntries.count == 1)
        #expect(errorEntries.first?.level == .error)
        
        // Test filtering by date range
        let startDate = context.dateProvider.now().addingTimeInterval(-3600)
        let endDate = context.dateProvider.now()
        let recentEntries = log.entries(from: startDate, to: endDate)
        #expect(recentEntries.count == entries.count)
        
        // Test filtering by source
        let sourceEntries = log.entries(fromSource: entries[0].source)
        #expect(sourceEntries.count == 1)
        #expect(sourceEntries.first?.source == entries[0].source)
    }
    
    // MARK: - Entry Export Tests
    
    @Test("Test log entry export", tags: ["export", "log"])
    func testEntryExport() throws {
        // Given: Log with entries
        let context = TestContext()
        let log = context.createLog()
        
        let entries = [
            MockData.Log.validEntry,
            MockData.Log.errorEntry,
            MockData.Log.customEntry
        ]
        
        for entry in entries {
            log.add(entry)
        }
        
        // When: Exporting entries
        let exportPath = "/tmp/test_log.json"
        try log.export(to: URL(fileURLWithPath: exportPath))
        
        // Then: File is created
        #expect(context.fileManager.fileExists(atPath: exportPath))
        
        // When: Importing entries
        let importedLog = context.createLog()
        try importedLog.import(from: URL(fileURLWithPath: exportPath))
        
        // Then: Entries match
        #expect(importedLog.entries.count == entries.count)
        for (original, imported) in zip(log.entries, importedLog.entries) {
            #expect(original == imported)
        }
    }
    
    // MARK: - Entry Search Tests
    
    @Test("Test log entry search", tags: ["search", "log"])
    func testEntrySearch() throws {
        // Given: Log with entries
        let context = TestContext()
        let log = context.createLog()
        
        let entries = [
            MockData.Log.validEntry,
            MockData.Log.errorEntry,
            MockData.Log.customEntry
        ]
        
        for entry in entries {
            log.add(entry)
        }
        
        // Test searching by message
        let messageResults = log.search(query: entries[0].message)
        #expect(messageResults.count == 1)
        #expect(messageResults.first?.message == entries[0].message)
        
        // Test searching by metadata
        let metadataResults = log.search(query: "error")
        #expect(metadataResults.count == 1)
        #expect(metadataResults.first?.level == .error)
        
        // Test searching with no results
        let noResults = log.search(query: "nonexistent")
        #expect(noResults.isEmpty)
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle log edge cases", tags: ["edge", "log"])
    func testEdgeCases() throws {
        // Given: Log
        let context = TestContext()
        let log = context.createLog()
        
        // Test empty log export
        let emptyExportPath = "/tmp/empty_log.json"
        try log.export(to: URL(fileURLWithPath: emptyExportPath))
        #expect(context.fileManager.fileExists(atPath: emptyExportPath))
        
        // Test invalid import path
        do {
            try log.import(from: URL(fileURLWithPath: "/nonexistent/path.json"))
            throw TestFailure("Expected error for invalid import path")
        } catch {
            // Expected error
        }
        
        // Test max entries edge case
        log.maxEntries = 1
        log.add(MockData.Log.validEntry)
        log.add(MockData.Log.errorEntry)
        #expect(log.entries.count == 1)
        #expect(log.entries.first == MockData.Log.errorEntry)
        
        // Test disabled log
        log.isEnabled = false
        log.add(MockData.Log.customEntry)
        #expect(log.entries.count == 1)
        #expect(!context.notificationCenter.postCalled)
    }
    
    // MARK: - Performance Tests
    
    @Test("Test log performance", tags: ["performance", "log"])
    func testPerformance() throws {
        // Given: Log
        let context = TestContext()
        let log = context.createLog()
        
        // Test bulk entry addition
        let startTime = context.dateProvider.now()
        for _ in 0..<1000 {
            log.add(MockData.Log.validEntry)
        }
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test memory usage
        #expect(log.entries.count <= BackupLog.defaultMaxEntries)
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
    var files: Set<String> = []
    var directories: Set<String> = []
    
    override func fileExists(atPath path: String) -> Bool {
        files.contains(path)
    }
    
    override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        if let isDirectory = isDirectory {
            isDirectory.pointee = ObjCBool(directories.contains(path))
        }
        return files.contains(path) || directories.contains(path)
    }
    
    func addFile(_ path: String) {
        files.insert(path)
    }
    
    func addDirectory(_ path: String) {
        directories.insert(path)
    }
    
    func reset() {
        files.removeAll()
        directories.removeAll()
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

/// Mock implementation of NotificationCenter for testing
final class MockNotificationCenter: NotificationCenter {
    var postCalled = false
    var lastNotification: Notification?
    
    override func post(_ notification: Notification) {
        postCalled = true
        lastNotification = notification
    }
    
    func reset() {
        postCalled = false
        lastNotification = nil
    }
}
