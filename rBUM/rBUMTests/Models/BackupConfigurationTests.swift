//
//  BackupConfigurationTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Testing
@testable import rBUM
import TestMocksModule

/// Tests for BackupConfiguration functionality
struct BackupConfigurationTests {
    // MARK: - Test Context
    
    /// Type aliases for mock implementations
    private typealias TestMocks = TestMocksModule.TestMocks
    private typealias MockUserDefaults = TestMocks.MockUserDefaults
    private typealias MockFileManager = TestMocks.MockFileManager
    private typealias MockNotificationCenter = TestMocks.MockNotificationCenter
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let fileManager: MockFileManager
        let notificationCenter: MockNotificationCenter
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.fileManager = MockFileManager()
            self.notificationCenter = MockNotificationCenter()
        }
        
        func createConfiguration(
            id: String = UUID().uuidString,
            name: String = "Test Configuration",
            description: String? = nil,
            enabled: Bool = true,
            schedule: BackupSchedule = .manual,
            sources: [BackupSource] = [],
            excludedPaths: [URL] = [],
            tags: [BackupTag] = []
        ) -> BackupConfiguration {
            BackupConfiguration(
                id: id,
                name: name,
                description: description,
                enabled: enabled,
                schedule: schedule,
                sources: sources,
                excludedPaths: excludedPaths,
                tags: tags
            )
        }
        
        func reset() {
            userDefaults.reset()
            fileManager.reset()
            notificationCenter.reset()
        }
    }
    
    // MARK: - Tests
    
    func testBasicProperties() throws {
        // Given: Configuration with default values
        let context = TestContext()
        let config = context.createConfiguration()
        
        // Then: Properties should match
        XCTAssertNotEmpty(config.id)
        XCTAssertEqual(config.name, "Test Configuration")
        XCTAssertNil(config.description)
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.schedule, .manual)
        XCTAssertEmpty(config.sources)
        XCTAssertEmpty(config.excludedPaths)
        XCTAssertEmpty(config.tags)
    }
    
    func testCustomValues() throws {
        // Given: Configuration with custom values
        let context = TestContext()
        let sources = [
            BackupSource(path: URL(fileURLWithPath: "/test/path1")),
            BackupSource(path: URL(fileURLWithPath: "/test/path2"))
        ]
        let excludedPaths = [
            URL(fileURLWithPath: "/test/excluded1"),
            URL(fileURLWithPath: "/test/excluded2")
        ]
        let tags = [
            BackupTag(name: "tag1"),
            BackupTag(name: "tag2")
        ]
        
        let config = context.createConfiguration(
            name: "Custom Config",
            description: "Test Description",
            enabled: false,
            schedule: .daily,
            sources: sources,
            excludedPaths: excludedPaths,
            tags: tags
        )
        
        // Then: Properties should match custom values
        XCTAssertEqual(config.name, "Custom Config")
        XCTAssertEqual(config.description, "Test Description")
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.schedule, .daily)
        XCTAssertEqual(config.sources, sources)
        XCTAssertEqual(config.excludedPaths, excludedPaths)
        XCTAssertEqual(config.tags, tags)
    }
    
    func testPersistence() throws {
        // Given: Configuration with custom values
        let context = TestContext()
        let config = context.createConfiguration(
            id: "test-id",
            name: "Test Config",
            description: "Test Description",
            enabled: true,
            schedule: .daily,
            sources: [
                BackupSource(path: URL(fileURLWithPath: "/test/path"))
            ],
            excludedPaths: [
                URL(fileURLWithPath: "/test/excluded")
            ],
            tags: [
                BackupTag(name: "test-tag")
            ]
        )
        
        // When: Configuration is saved and loaded
        try config.save(to: context.userDefaults)
        let loaded = try BackupConfiguration.load(from: context.userDefaults, forId: config.id)
        
        // Then: Loaded configuration should match original
        XCTAssertEqual(loaded?.id, config.id)
        XCTAssertEqual(loaded?.name, config.name)
        XCTAssertEqual(loaded?.description, config.description)
        XCTAssertEqual(loaded?.enabled, config.enabled)
        XCTAssertEqual(loaded?.schedule, config.schedule)
        XCTAssertEqual(loaded?.sources, config.sources)
        XCTAssertEqual(loaded?.excludedPaths, config.excludedPaths)
        XCTAssertEqual(loaded?.tags, config.tags)
    }
    
    func testEdgeCases() throws {
        // Given: Edge case scenarios
        let context = TestContext()
        
        // Test nil UserDefaults
        XCTAssertThrowsError(try BackupConfiguration.load(from: context.userDefaults, forId: "non-existent"))
        
        // Test empty configuration
        let emptyConfig = context.createConfiguration(
            name: "",
            description: "",
            sources: [],
            excludedPaths: [],
            tags: []
        )
        try emptyConfig.save(to: context.userDefaults)
        let loaded = try BackupConfiguration.load(from: context.userDefaults, forId: emptyConfig.id)
        XCTAssertEqual(loaded?.name, "")
        XCTAssertEqual(loaded?.description, "")
        XCTAssertEmpty(loaded?.sources ?? [])
        XCTAssertEmpty(loaded?.excludedPaths ?? [])
        XCTAssertEmpty(loaded?.tags ?? [])
    }
}
