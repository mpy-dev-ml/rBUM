//
//  ConfigurationStorageTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM
import Foundation

/// Tests for ConfigurationStorage functionality
struct ConfigurationStorageTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let fileManager: TestMocksModule.TestMocks.MockFileManager
        let notificationCenter: TestMocksModule.TestMocks.MockNotificationCenter
        let encoder: JSONEncoder
        let decoder: JSONDecoder
        
        init() {
            self.fileManager = TestMocksModule.TestMocks.MockFileManager()
            self.notificationCenter = TestMocksModule.TestMocks.MockNotificationCenter()
            self.encoder = JSONEncoder()
            self.decoder = JSONDecoder()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            fileManager.reset()
            notificationCenter.reset()
        }
        
        /// Create test configuration storage
        func createStorage() -> ConfigurationStorage {
            ConfigurationStorage(
                fileManager: fileManager as FileManagerProtocol,
                notificationCenter: notificationCenter
            )
        }
    }
    
    // MARK: - Storage Tests
    
    @Test("Test basic configuration storage", ["storage", "config"] as! TestTrait)
    func testBasicStorage() throws {
        // Given: Configuration storage
        let context = TestContext()
        let storage = context.createStorage()
        
        // When: Save new configuration
        let config = Configuration.default
        try storage.save(config)
        
        // Then: Configuration was saved
        #expect(context.fileManager.writeDataCalled)
        
        // When: Load configuration
        let loaded = try storage.load()
        
        // Then: Configuration matches
        #expect(loaded == config)
        
        // Then: Notification was posted
        #expect(context.notificationCenter.lastPostedName == .configurationDidChange)
    }
    
    @Test("Test configuration reset", ["storage", "config"] as! TestTrait)
    func testConfigurationReset() throws {
        // Given: Configuration storage with saved config
        let context = TestContext()
        let storage = context.createStorage()
        let config = Configuration.default
        try storage.save(config)
        
        // When: Reset configuration
        try storage.reset()
        
        // Then: Configuration was reset to default
        let loaded = try storage.load()
        #expect(loaded == Configuration.default)
        
        // Then: Notification was posted
        #expect(context.notificationCenter.lastPostedName == .configurationDidChange)
    }
    
    @Test("Test error handling", ["storage", "config", "error"] as! TestTrait)
    func testErrorHandling() throws {
        // Given: Configuration storage with error
        let context = TestContext()
        context.fileManager.simulateError(ConfigurationStorageError.fileOperationFailed("write"))
        let storage = context.createStorage()
        
        // When: Try to save configuration
        do {
            try storage.save(Configuration.default)
            throw TestFailure("Expected error")
        } catch ConfigurationStorageError.fileOperationFailed {
            // Expected error
        }
        
        // Then: No notification was posted
        #expect(context.notificationCenter.lastPostedName == nil)
    }
    
    // MARK: - Backup Tests
    
    @Test("Test configuration backup", ["backup", "config"] as! TestTrait)
    func testConfigurationBackup() throws {
        // Given: Configuration storage
        let context = TestContext()
        let storage = context.createStorage()
        
        // When: Save configuration
        let config = Configuration.default
        try storage.save(config)
        
        // Then: File exists
        var isDirectory = ObjCBool(false)
        let exists = context.fileManager.fileExists(atPath: "/mock/\(FileManager.SearchPathDirectory.applicationSupportDirectory.rawValue)/config.json", isDirectory: &isDirectory)
        #expect(exists)
        #expect(!isDirectory.boolValue)
    }
}
