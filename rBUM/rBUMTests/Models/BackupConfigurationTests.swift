//
//  BackupConfigurationTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupConfiguration functionality
struct BackupConfigurationTests {
    // MARK: - Test Context
    
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
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            fileManager.reset()
            notificationCenter.reset()
        }
        
        /// Create test configuration
        func createConfiguration(
            id: String = MockData.Configuration.validId,
            name: String = MockData.Configuration.validName,
            sourcePaths: [String] = MockData.Configuration.validSourcePaths,
            excludePatterns: [String] = MockData.Configuration.validExcludePatterns,
            includePatterns: [String] = MockData.Configuration.validIncludePatterns,
            schedule: BackupSchedule = MockData.Schedule.validSchedule,
            repository: Repository = MockData.Repository.validRepository,
            isEnabled: Bool = true
        ) -> BackupConfiguration {
            BackupConfiguration(
                id: id,
                name: name,
                sourcePaths: sourcePaths,
                excludePatterns: excludePatterns,
                includePatterns: includePatterns,
                schedule: schedule,
                repository: repository,
                isEnabled: isEnabled
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize with default values", tags: ["init", "configuration"])
    func testDefaultInitialization() throws {
        // Given: Default configuration parameters
        let context = TestContext()
        
        // When: Creating configuration
        let config = context.createConfiguration()
        
        // Then: Configuration is configured correctly
        #expect(config.id == MockData.Configuration.validId)
        #expect(config.name == MockData.Configuration.validName)
        #expect(config.sourcePaths == MockData.Configuration.validSourcePaths)
        #expect(config.excludePatterns == MockData.Configuration.validExcludePatterns)
        #expect(config.includePatterns == MockData.Configuration.validIncludePatterns)
        #expect(config.schedule == MockData.Schedule.validSchedule)
        #expect(config.repository == MockData.Repository.validRepository)
        #expect(config.isEnabled)
    }
    
    @Test("Initialize with custom values", tags: ["init", "configuration"])
    func testCustomInitialization() throws {
        // Given: Custom configuration parameters
        let context = TestContext()
        let customId = "custom-id"
        let customName = "Custom Backup"
        let customSourcePaths = ["/custom/path1", "/custom/path2"]
        let customExcludePatterns = ["*.tmp", "*.log"]
        let customIncludePatterns = ["*.doc", "*.pdf"]
        let customSchedule = MockData.Schedule.customSchedule
        let customRepository = MockData.Repository.customRepository
        
        // When: Creating configuration
        let config = context.createConfiguration(
            id: customId,
            name: customName,
            sourcePaths: customSourcePaths,
            excludePatterns: customExcludePatterns,
            includePatterns: customIncludePatterns,
            schedule: customSchedule,
            repository: customRepository,
            isEnabled: false
        )
        
        // Then: Configuration is configured correctly
        #expect(config.id == customId)
        #expect(config.name == customName)
        #expect(config.sourcePaths == customSourcePaths)
        #expect(config.excludePatterns == customExcludePatterns)
        #expect(config.includePatterns == customIncludePatterns)
        #expect(config.schedule == customSchedule)
        #expect(config.repository == customRepository)
        #expect(!config.isEnabled)
    }
    
    // MARK: - Persistence Tests
    
    @Test("Save and load configuration", tags: ["persistence", "configuration"])
    func testPersistence() throws {
        // Given: Configuration with custom values
        let context = TestContext()
        let config = context.createConfiguration(
            id: "test-id",
            name: "Test Backup",
            sourcePaths: ["/test/path1", "/test/path2"],
            excludePatterns: ["*.tmp"],
            includePatterns: ["*.doc"],
            isEnabled: false
        )
        
        // When: Saving and loading configuration
        config.save(to: context.userDefaults)
        let loaded = BackupConfiguration.load(from: context.userDefaults, withId: config.id)
        
        // Then: Loaded configuration matches original
        #expect(loaded?.id == config.id)
        #expect(loaded?.name == config.name)
        #expect(loaded?.sourcePaths == config.sourcePaths)
        #expect(loaded?.excludePatterns == config.excludePatterns)
        #expect(loaded?.includePatterns == config.includePatterns)
        #expect(loaded?.schedule == config.schedule)
        #expect(loaded?.repository == config.repository)
        #expect(loaded?.isEnabled == config.isEnabled)
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate configuration", tags: ["validation", "configuration"])
    func testValidation() throws {
        // Given: Configurations with various validation scenarios
        let context = TestContext()
        let testCases: [(BackupConfiguration, Bool)] = [
            // Valid configuration
            (context.createConfiguration(), true),
            
            // Invalid - empty name
            (context.createConfiguration(name: ""), false),
            
            // Invalid - empty source paths
            (context.createConfiguration(sourcePaths: []), false),
            
            // Invalid - empty repository
            (context.createConfiguration(repository: MockData.Repository.invalidRepository), false),
            
            // Invalid - invalid schedule
            (context.createConfiguration(schedule: MockData.Schedule.invalidSchedule), false)
        ]
        
        // When/Then: Test validation
        for (config, isValid) in testCases {
            #expect(config.isValid() == isValid)
        }
    }
    
    // MARK: - Source Path Tests
    
    @Test("Handle source paths", tags: ["paths", "configuration"])
    func testSourcePaths() throws {
        // Given: Configuration with source paths
        let context = TestContext()
        let testCases: [(BackupConfiguration, String, Bool)] = [
            // Valid paths
            (context.createConfiguration(sourcePaths: ["/test/path1"]), "/test/path1", true),
            (context.createConfiguration(sourcePaths: ["/test/path1", "/test/path2"]), "/test/path2", true),
            
            // Invalid paths
            (context.createConfiguration(sourcePaths: ["/test/path1"]), "/test/path2", false),
            (context.createConfiguration(sourcePaths: []), "/test/path1", false)
        ]
        
        // When/Then: Test source path handling
        for (config, path, contains) in testCases {
            #expect(config.containsSourcePath(path) == contains)
        }
    }
    
    // MARK: - Pattern Tests
    
    @Test("Handle patterns", tags: ["patterns", "configuration"])
    func testPatterns() throws {
        // Given: Configuration with patterns
        let context = TestContext()
        let config = context.createConfiguration(
            excludePatterns: ["*.tmp", "*.log"],
            includePatterns: ["*.doc", "*.pdf"]
        )
        
        // Test exclude patterns
        #expect(config.shouldExclude("test.tmp"))
        #expect(config.shouldExclude("test.log"))
        #expect(!config.shouldExclude("test.doc"))
        
        // Test include patterns
        #expect(config.shouldInclude("test.doc"))
        #expect(config.shouldInclude("test.pdf"))
        #expect(!config.shouldInclude("test.tmp"))
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle edge cases", tags: ["edge", "configuration"])
    func testEdgeCases() throws {
        // Given: Edge case scenarios
        let context = TestContext()
        
        // Test nil UserDefaults
        let nilDefaults = MockUserDefaults()
        nilDefaults.removeObject(forKey: BackupConfiguration.defaultsKey)
        let loadedConfig = BackupConfiguration.load(from: nilDefaults, withId: "test-id")
        #expect(loadedConfig == nil)
        
        // Test empty patterns
        let emptyPatternConfig = context.createConfiguration(
            excludePatterns: [],
            includePatterns: []
        )
        #expect(!emptyPatternConfig.shouldExclude("test.file"))
        #expect(emptyPatternConfig.shouldInclude("test.file"))
        
        // Test duplicate source paths
        let duplicatePaths = ["/test/path", "/test/path"]
        let duplicateConfig = context.createConfiguration(sourcePaths: duplicatePaths)
        #expect(duplicateConfig.sourcePaths.count == 1)
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
