//
//  ConfigurationStorageTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
@testable import rBUM

final class ConfigurationStorageTests: XCTestCase {
    var storage: ConfigurationStorage!
    var testURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev.mpy.rBUM.tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        testURL = tempDir.appendingPathComponent("config.json")
        storage = ConfigurationStorage(fileManager: FileManager.default, storageURL: testURL)
    }
    
    override func tearDown() async throws {
        if let testURL = testURL {
            try? FileManager.default.removeItem(at: testURL.deletingLastPathComponent())
        }
        storage = nil
        testURL = nil
        try await super.tearDown()
    }
    
    func testLoadDefaultConfiguration() throws {
        // When loading without existing config
        let config = try storage.load()
        
        // Then default values should be used
        XCTAssertEqual(config.defaultBackupInterval, 0)
        XCTAssertEqual(config.maxConcurrentBackups, 1)
        XCTAssertTrue(config.showBackupNotifications)
        XCTAssertTrue(config.autoCheckRepositoryHealth)
        XCTAssertEqual(config.repositoryHealthCheckInterval, 7)
        XCTAssertFalse(config.autoCleanupSnapshots)
        XCTAssertEqual(config.keepSnapshotsForDays, 30)
        XCTAssertEqual(config.defaultCompressionLevel, 6)
        XCTAssertTrue(config.excludeSystemCaches)
        XCTAssertFalse(config.defaultExcludePaths.isEmpty)
    }
    
    func testSaveAndLoadConfiguration() throws {
        // Given a custom configuration
        var config = Configuration.default
        config.defaultBackupInterval = 60
        config.maxConcurrentBackups = 2
        config.showBackupNotifications = false
        
        // When saving and loading
        try storage.save(config)
        let loaded = try storage.load()
        
        // Then values should match
        XCTAssertEqual(loaded.defaultBackupInterval, 60)
        XCTAssertEqual(loaded.maxConcurrentBackups, 2)
        XCTAssertFalse(loaded.showBackupNotifications)
    }
    
    func testResetConfiguration() throws {
        // Given a custom configuration
        var config = Configuration.default
        config.defaultBackupInterval = 60
        config.maxConcurrentBackups = 2
        try storage.save(config)
        
        // When resetting
        try storage.reset()
        let loaded = try storage.load()
        
        // Then values should be back to defaults
        XCTAssertEqual(loaded.defaultBackupInterval, 0)
        XCTAssertEqual(loaded.maxConcurrentBackups, 1)
        XCTAssertTrue(loaded.showBackupNotifications)
    }
    
    func testSaveInvalidDirectory() throws {
        // Given a storage with invalid directory
        let invalidURL = URL(fileURLWithPath: "/invalid/path/config.json")
        let invalidStorage = ConfigurationStorage(
            fileManager: FileManager.default,
            storageURL: invalidURL
        )
        
        // When trying to save
        XCTAssertThrowsError(try invalidStorage.save(Configuration.default)) { error in
            // Then should get file operation error
            XCTAssertEqual(error as? ConfigurationStorageError, .fileOperationFailed("write"))
        }
    }
    
    func testLoadInvalidData() throws {
        // Given invalid JSON data
        let invalidData = "invalid json".data(using: .utf8)!
        try invalidData.write(to: testURL)
        
        // When trying to load
        XCTAssertThrowsError(try storage.load()) { error in
            // Then should get file operation error
            XCTAssertEqual(error as? ConfigurationStorageError, .fileOperationFailed("read"))
        }
    }
}
