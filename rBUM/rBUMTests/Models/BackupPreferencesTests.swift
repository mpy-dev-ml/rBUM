//
//  BackupPreferencesTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupPreferences functionality
struct BackupPreferencesTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let notificationCenter: MockNotificationCenter
        let dateProvider: MockDateProvider
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.notificationCenter = MockNotificationCenter()
            self.dateProvider = MockDateProvider()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            notificationCenter.reset()
            dateProvider.reset()
        }
        
        /// Create test preferences manager
        func createPreferencesManager() -> BackupPreferencesManager {
            BackupPreferencesManager(
                userDefaults: userDefaults,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup preferences manager", tags: ["init", "preferences"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating preferences manager
        let manager = context.createPreferencesManager()
        
        // Then: Manager is configured with default values
        #expect(manager.preferences.count == MockData.Preferences.defaultCount)
        #expect(manager.getPreference(MockData.Preferences.autoBackupKey) as? Bool == true)
        #expect(manager.getPreference(MockData.Preferences.backupIntervalKey) as? Int == 3600)
    }
    
    // MARK: - Preference Management Tests
    
    @Test("Test preference management", tags: ["preferences", "core"])
    func testPreferenceManagement() throws {
        // Given: Preferences manager
        let context = TestContext()
        let manager = context.createPreferencesManager()
        
        // Test setting preferences
        for (key, value) in MockData.Preferences.validPreferences {
            try manager.setPreference(value, forKey: key)
            #expect(manager.getPreference(key) as? String == value)
            #expect(context.userDefaults.setValueCalled)
            
            context.reset()
        }
        
        // Test removing preferences
        let keyToRemove = MockData.Preferences.validPreferences.first!.key
        try manager.removePreference(forKey: keyToRemove)
        #expect(manager.getPreference(keyToRemove) == nil)
        #expect(context.userDefaults.removeValueCalled)
    }
    
    // MARK: - Type Safety Tests
    
    @Test("Test preference type safety", tags: ["preferences", "types"])
    func testTypeSafety() throws {
        // Given: Preferences manager
        let context = TestContext()
        let manager = context.createPreferencesManager()
        
        // Test different value types
        try manager.setPreference(true, forKey: "boolPref")
        try manager.setPreference(42, forKey: "intPref")
        try manager.setPreference(3.14, forKey: "doublePref")
        try manager.setPreference("test", forKey: "stringPref")
        try manager.setPreference(["a", "b"], forKey: "arrayPref")
        try manager.setPreference(["key": "value"], forKey: "dictPref")
        
        // Verify type safety
        #expect(manager.getPreference("boolPref") as? Bool == true)
        #expect(manager.getPreference("intPref") as? Int == 42)
        #expect(manager.getPreference("doublePref") as? Double == 3.14)
        #expect(manager.getPreference("stringPref") as? String == "test")
        #expect((manager.getPreference("arrayPref") as? [String])?.count == 2)
        #expect((manager.getPreference("dictPref") as? [String: String])?.count == 1)
    }
    
    // MARK: - Validation Tests
    
    @Test("Test preference validation", tags: ["preferences", "validation"])
    func testValidation() throws {
        // Given: Preferences manager
        let context = TestContext()
        let manager = context.createPreferencesManager()
        
        // Test invalid keys
        for key in MockData.Preferences.invalidKeys {
            do {
                try manager.setPreference("test", forKey: key)
                throw TestFailure("Expected error for invalid key: \(key)")
            } catch {
                // Expected error
            }
        }
        
        // Test invalid values
        for value in MockData.Preferences.invalidValues {
            do {
                try manager.setPreference(value, forKey: "testKey")
                throw TestFailure("Expected error for invalid value: \(value)")
            } catch {
                // Expected error
            }
        }
    }
    
    // MARK: - Notification Tests
    
    @Test("Test preference change notifications", tags: ["preferences", "notifications"])
    func testNotifications() throws {
        // Given: Preferences manager
        let context = TestContext()
        let manager = context.createPreferencesManager()
        
        // Test notification posting
        let testKey = "testKey"
        let testValue = "testValue"
        
        try manager.setPreference(testValue, forKey: testKey)
        #expect(context.notificationCenter.postNotificationCalled)
        
        // Verify notification details
        let notification = context.notificationCenter.lastPostedNotification
        #expect(notification?.name == .backupPreferencesChanged)
        #expect((notification?.userInfo?["key"] as? String) == testKey)
        #expect((notification?.userInfo?["value"] as? String) == testValue)
    }
    
    // MARK: - Persistence Tests
    
    @Test("Test preferences persistence", tags: ["preferences", "persistence"])
    func testPersistence() throws {
        // Given: Preferences manager with preferences
        let context = TestContext()
        let manager = context.createPreferencesManager()
        
        // Set test preferences
        for (key, value) in MockData.Preferences.validPreferences {
            try manager.setPreference(value, forKey: key)
        }
        
        // When: Saving state
        try manager.save()
        
        // Then: State is persisted
        let loadedManager = context.createPreferencesManager()
        try loadedManager.load()
        
        for (key, value) in MockData.Preferences.validPreferences {
            #expect(loadedManager.getPreference(key) as? String == value)
        }
    }
    
    // MARK: - Migration Tests
    
    @Test("Test preferences migration", tags: ["preferences", "migration"])
    func testMigration() throws {
        // Given: Preferences manager with old format
        let context = TestContext()
        let manager = context.createPreferencesManager()
        
        // Set old format preferences
        for (key, value) in MockData.Preferences.oldFormatPreferences {
            context.userDefaults.setValue(value, forKey: key)
        }
        
        // When: Migrating preferences
        try manager.migratePreferences()
        
        // Then: Preferences are in new format
        for (key, value) in MockData.Preferences.oldFormatPreferences {
            let newKey = key.replacingOccurrences(of: "old", with: "new")
            #expect(manager.getPreference(newKey) as? String == value)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle preferences edge cases", tags: ["preferences", "edge"])
    func testEdgeCases() throws {
        // Given: Preferences manager
        let context = TestContext()
        let manager = context.createPreferencesManager()
        
        // Test empty key
        do {
            try manager.setPreference("test", forKey: "")
            throw TestFailure("Expected error for empty key")
        } catch {
            // Expected error
        }
        
        // Test nil value removal
        try manager.setPreference(nil, forKey: "testKey")
        #expect(manager.getPreference("testKey") == nil)
        
        // Test overwriting existing preference
        try manager.setPreference("value1", forKey: "testKey")
        try manager.setPreference("value2", forKey: "testKey")
        #expect(manager.getPreference("testKey") as? String == "value2")
    }
    
    // MARK: - Performance Tests
    
    @Test("Test preferences performance", tags: ["preferences", "performance"])
    func testPerformance() throws {
        // Given: Preferences manager
        let context = TestContext()
        let manager = context.createPreferencesManager()
        
        // Test rapid preference updates
        let startTime = context.dateProvider.now()
        for i in 0..<1000 {
            try manager.setPreference("value\(i)", forKey: "key\(i)")
        }
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test preference lookup performance
        let lookupStartTime = context.dateProvider.now()
        for i in 0..<1000 {
            _ = manager.getPreference("key\(i)")
        }
        let lookupEndTime = context.dateProvider.now()
        
        let lookupInterval = lookupEndTime.timeIntervalSince(lookupStartTime)
        #expect(lookupInterval < 0.1) // Preference lookups should be fast
    }
}

// MARK: - Mock User Defaults

/// Mock implementation of UserDefaults for testing
final class MockUserDefaults: UserDefaultsProtocol {
    private var storage: [String: Any] = [:]
    private(set) var setValueCalled = false
    private(set) var removeValueCalled = false
    
    func setValue(_ value: Any?, forKey key: String) {
        setValueCalled = true
        storage[key] = value
    }
    
    func value(forKey key: String) -> Any? {
        storage[key]
    }
    
    func removeValue(forKey key: String) {
        removeValueCalled = true
        storage.removeValue(forKey: key)
    }
    
    func reset() {
        storage.removeAll()
        setValueCalled = false
        removeValueCalled = false
    }
}

// MARK: - Mock Notification Center

/// Mock implementation of NotificationCenter for testing
final class MockNotificationCenter: NotificationCenterProtocol {
    private(set) var postNotificationCalled = false
    private(set) var lastPostedNotification: Notification?
    
    func post(name: Notification.Name, object: Any?, userInfo: [AnyHashable: Any]?) {
        postNotificationCalled = true
        lastPostedNotification = Notification(name: name, object: object, userInfo: userInfo)
    }
    
    func reset() {
        postNotificationCalled = false
        lastPostedNotification = nil
    }
}

// MARK: - Mock Date Provider

/// Mock implementation of DateProvider for testing
final class MockDateProvider: DateProviderProtocol {
    private var currentDate = Date()
    
    func now() -> Date {
        currentDate
    }
    
    func advanceTime(by interval: TimeInterval) {
        currentDate = currentDate.addingTimeInterval(interval)
    }
    
    func reset() {
        currentDate = Date()
    }
}
