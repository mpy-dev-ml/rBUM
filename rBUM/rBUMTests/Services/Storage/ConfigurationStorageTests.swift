//
//  ConfigurationStorageTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for ConfigurationStorage functionality
struct ConfigurationStorageTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let fileManager: MockFileManager
        let notificationCenter: MockNotificationCenter
        let encoder: JSONEncoder
        let decoder: JSONDecoder
        let userDefaults: MockUserDefaults
        
        init() {
            self.fileManager = MockFileManager()
            self.notificationCenter = MockNotificationCenter()
            self.encoder = JSONEncoder()
            self.decoder = JSONDecoder()
            self.userDefaults = MockUserDefaults()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            fileManager.reset()
            notificationCenter.reset()
            userDefaults.reset()
        }
        
        /// Create test configuration storage
        func createStorage() -> ConfigurationStorage {
            ConfigurationStorage(
                fileManager: fileManager,
                notificationCenter: notificationCenter,
                encoder: encoder,
                decoder: decoder,
                userDefaults: userDefaults
            )
        }
    }
    
    // MARK: - Storage Tests
    
    @Test("Test configuration storage operations", tags: ["storage", "config"])
    func testStorageOperations() throws {
        // Given: Configuration storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Configuration.storageData
        
        // Test storage operations
        for testCase in testCases {
            // Store configuration
            try storage.store(testCase.config)
            #expect(context.fileManager.writeDataCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Load configuration
            let loaded = try storage.load(testCase.config.id)
            #expect(loaded == testCase.config)
            #expect(context.fileManager.readDataCalled)
            
            // Update configuration
            var updated = testCase.config
            updated.name = "Updated Configuration"
            try storage.update(updated)
            #expect(context.fileManager.writeDataCalled)
            
            // Delete configuration
            try storage.delete(updated.id)
            #expect(context.fileManager.deleteFileCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Test configuration validation", tags: ["validation", "config"])
    func testConfigurationValidation() throws {
        // Given: Configuration storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Configuration.validationData
        
        // Test validation
        for testCase in testCases {
            do {
                // Validate configuration
                try storage.validate(testCase.config)
                
                if !testCase.expectedValid {
                    throw TestFailure("Expected validation error for invalid data")
                }
            } catch {
                if testCase.expectedValid {
                    throw TestFailure("Unexpected validation error: \(error)")
                }
                
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .configurationValidationError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Default Configuration Tests
    
    @Test("Test default configuration", tags: ["defaults", "config"])
    func testDefaultConfiguration() throws {
        // Given: Configuration storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Configuration.defaultData
        
        // Test default configurations
        for testCase in testCases {
            // Set user defaults
            context.userDefaults.mockDefaults = testCase.defaults
            
            // Load default configuration
            let config = try storage.loadDefault()
            
            // Verify default configuration
            #expect(config.settings == testCase.expectedSettings)
            #expect(config.preferences == testCase.expectedPreferences)
            
            // Store as default
            try storage.storeDefault(config)
            #expect(context.userDefaults.setValueCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Migration Tests
    
    @Test("Test configuration migration", tags: ["migration", "config"])
    func testConfigurationMigration() throws {
        // Given: Configuration storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Configuration.migrationData
        
        // Test migration
        for testCase in testCases {
            // Setup old data
            context.fileManager.mockData = testCase.oldData
            
            // Perform migration
            try storage.migrate()
            
            // Verify migration
            let migratedData = context.fileManager.lastWrittenData
            #expect(migratedData == testCase.expectedData)
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test configuration error handling", tags: ["error", "config"])
    func testErrorHandling() throws {
        // Given: Configuration storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let errorCases = MockData.Configuration.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                // Simulate error condition
                context.fileManager.simulateError = errorCase.error
                
                // Attempt operation
                try errorCase.operation(storage)
                
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Verify error handling
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .configurationStorageError)
                
                // Verify error details
                if let configError = error as? ConfigurationError {
                    #expect(configError.code == errorCase.expectedErrorCode)
                }
            }
            
            context.reset()
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test configuration performance", tags: ["performance", "config"])
    func testPerformance() throws {
        // Given: Configuration storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let startTime = Date()
        
        // Perform multiple operations
        for i in 0..<100 {
            let config = BackupConfiguration(
                id: UUID(),
                name: "Test Config \(i)",
                settings: BackupSettings(),
                schedule: BackupSchedule()
            )
            try storage.store(config)
            _ = try storage.load(config.id)
            try storage.delete(config.id)
        }
        
        let endTime = Date()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 5.0) // Should complete in under 5 seconds
        
        // Test individual operation performance
        let config = BackupConfiguration(
            id: UUID(),
            name: "Test Config",
            settings: BackupSettings(),
            schedule: BackupSchedule()
        )
        
        let operationStart = Date()
        try storage.store(config)
        _ = try storage.load(config.id)
        try storage.delete(config.id)
        let operationEnd = Date()
        
        let operationInterval = operationEnd.timeIntervalSince(operationStart)
        #expect(operationInterval < 0.1) // Individual operations should be fast
    }
    
    // MARK: - Backup Tests
    
    @Test("Test configuration backup", tags: ["backup", "config"])
    func testConfigurationBackup() throws {
        // Given: Configuration storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Configuration.backupData
        
        // Test backup operations
        for testCase in testCases {
            // Create backup
            try storage.createBackup()
            #expect(context.fileManager.copyFileCalled)
            
            // Verify backup
            let backupExists = context.fileManager.fileExists(atPath: testCase.backupPath)
            #expect(backupExists)
            
            // Restore from backup
            try storage.restoreFromBackup()
            #expect(context.fileManager.copyFileCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify restored data
            let restoredData = try storage.load(testCase.config.id)
            #expect(restoredData == testCase.config)
            
            context.reset()
        }
    }
}
