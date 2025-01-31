//
//  ConfigurationStorageTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

struct ConfigurationStorageTests {
    // MARK: - Test Setup
    
    private static func createTestStorage() throws -> (ConfigurationStorage, URL) {
        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev.mpy.rBUM.tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let testURL = tempDir.appendingPathComponent("config.json")
        let storage = ConfigurationStorage(fileManager: FileManager.default, storageURL: testURL)
        
        return (storage, testURL)
    }
    
    private static func cleanupTestStorage(_ url: URL) throws {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
    
    // MARK: - Basic Configuration Tests
    
    @Test("Load default configuration when no file exists", tags: ["basic", "storage"])
    func testLoadDefaultConfiguration() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        // When loading without existing config
        let config = try storage.load()
        
        // Then default values should be used
        #expect(config.defaultBackupInterval == 0)
        #expect(config.maxConcurrentBackups == 1)
        #expect(config.showBackupNotifications)
        #expect(config.autoCheckRepositoryHealth)
        #expect(config.repositoryHealthCheckInterval == 7)
        #expect(!config.autoCleanupSnapshots)
        #expect(config.keepSnapshotsForDays == 30)
        #expect(config.defaultCompressionLevel == 6)
        #expect(config.excludeSystemCaches)
        #expect(!config.defaultExcludePaths.isEmpty)
    }
    
    @Test("Save and load configuration successfully", tags: ["basic", "storage"])
    func testSaveAndLoadConfiguration() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        // Given a custom configuration
        var config = Configuration.default
        config.defaultBackupInterval = 60
        config.maxConcurrentBackups = 2
        config.showBackupNotifications = false
        
        // When saving and loading
        try storage.save(config)
        let loaded = try storage.load()
        
        // Then values should match
        #expect(loaded.defaultBackupInterval == 60)
        #expect(loaded.maxConcurrentBackups == 2)
        #expect(!loaded.showBackupNotifications)
    }
    
    @Test("Reset configuration to defaults", tags: ["basic", "storage"])
    func testResetConfiguration() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        // Given a custom configuration
        var config = Configuration.default
        config.defaultBackupInterval = 60
        config.maxConcurrentBackups = 2
        try storage.save(config)
        
        // When resetting
        try storage.reset()
        let loaded = try storage.load()
        
        // Then values should be back to defaults
        #expect(loaded.defaultBackupInterval == 0)
        #expect(loaded.maxConcurrentBackups == 1)
        #expect(loaded.showBackupNotifications)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle invalid directory paths", tags: ["error", "storage"])
    func testSaveInvalidDirectory() throws {
        // Given a storage with invalid directory
        let invalidURL = URL(fileURLWithPath: "/invalid/path/config.json")
        let invalidStorage = ConfigurationStorage(
            fileManager: FileManager.default,
            storageURL: invalidURL
        )
        
        // When trying to save
        var thrownError: Error?
        do {
            try invalidStorage.save(Configuration.default)
        } catch {
            thrownError = error
        }
        
        // Then should get file operation error
        #expect(thrownError != nil)
        if let error = thrownError as? ConfigurationStorageError {
            #expect(error == .fileOperationFailed("write"))
        }
    }
    
    @Test("Handle invalid JSON data", tags: ["error", "storage"])
    func testLoadInvalidData() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        // Given invalid JSON data
        let invalidData = "invalid json".data(using: .utf8)!
        try invalidData.write(to: url)
        
        // When trying to load
        var thrownError: Error?
        do {
            _ = try storage.load()
        } catch {
            thrownError = error
        }
        
        // Then should get file operation error
        #expect(thrownError != nil)
        if let error = thrownError as? ConfigurationStorageError {
            #expect(error == .fileOperationFailed("read"))
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Handle concurrent access safely", tags: ["concurrency", "storage"])
    func testConcurrentAccess() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        // Create multiple configurations
        let configs = (0..<5).map { i in
            var config = Configuration.default
            config.defaultBackupInterval = TimeInterval(i * 60)
            config.maxConcurrentBackups = i + 1
            return config
        }
        
        // Concurrently save and load configurations
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.mpy.rBUM.test", attributes: .concurrent)
        var errors: [Error] = []
        
        // Save configurations concurrently
        for config in configs {
            group.enter()
            queue.async {
                do {
                    try storage.save(config)
                    _ = try storage.load()
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
        
        // Load final configuration
        let finalConfig = try storage.load()
        #expect(finalConfig.defaultBackupInterval >= 0)
        #expect(finalConfig.maxConcurrentBackups >= 1)
    }
    
    // MARK: - Parameterized Tests
    
    @Test("Handle various configuration values", tags: ["parameterized", "storage"])
    func testConfigurationValues() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        let testCases = [
            // Test minimum values
            {
                var config = Configuration.default
                config.defaultBackupInterval = 0
                config.maxConcurrentBackups = 1
                config.keepSnapshotsForDays = 1
                config.defaultCompressionLevel = 0
                return config
            }(),
            // Test maximum values
            {
                var config = Configuration.default
                config.defaultBackupInterval = 86400 // 24 hours
                config.maxConcurrentBackups = 10
                config.keepSnapshotsForDays = 365
                config.defaultCompressionLevel = 9
                return config
            }(),
            // Test mixed boolean values
            {
                var config = Configuration.default
                config.showBackupNotifications = false
                config.autoCheckRepositoryHealth = false
                config.autoCleanupSnapshots = true
                config.excludeSystemCaches = false
                return config
            }(),
            // Test custom exclude paths
            {
                var config = Configuration.default
                config.defaultExcludePaths = [
                    "/custom/path1",
                    "/custom/path2",
                    "/path/with spaces",
                    "/path/with/special/chars/!@#$"
                ]
                return config
            }()
        ]
        
        for config in testCases {
            // Save configuration
            try storage.save(config)
            
            // Load and verify
            let loaded = try storage.load()
            #expect(loaded.defaultBackupInterval == config.defaultBackupInterval)
            #expect(loaded.maxConcurrentBackups == config.maxConcurrentBackups)
            #expect(loaded.showBackupNotifications == config.showBackupNotifications)
            #expect(loaded.autoCheckRepositoryHealth == config.autoCheckRepositoryHealth)
            #expect(loaded.keepSnapshotsForDays == config.keepSnapshotsForDays)
            #expect(loaded.defaultCompressionLevel == config.defaultCompressionLevel)
            #expect(loaded.excludeSystemCaches == config.excludeSystemCaches)
            #expect(loaded.defaultExcludePaths == config.defaultExcludePaths)
        }
    }
    
    @Test("Handle file system edge cases", tags: ["error", "storage"])
    func testFileSystemEdgeCases() throws {
        let (storage, url) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(url) }
        
        // Test cases for file system edge cases
        let testCases = [
            // Test directory already exists
            {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                var config = Configuration.default
                config.defaultBackupInterval = 30
                return config
            }(),
            // Test file with no write permissions
            {
                try "".write(to: url, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
                var config = Configuration.default
                config.defaultBackupInterval = 45
                return config
            }(),
            // Test file in read-only directory
            {
                let readOnlyDir = url.deletingLastPathComponent()
                try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnlyDir.path)
                var config = Configuration.default
                config.defaultBackupInterval = 60
                return config
            }()
        ]
        
        for config in testCases {
            var thrownError: Error?
            do {
                try storage.save(config)
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
