import Foundation
@testable import rBUM
import Testing
import TestMocksModule

/// Tests for BackupConfiguration functionality
struct BackupConfigurationTests {
    // MARK: - Test Context
    
    /// Type aliases for mock implementations
    private typealias TestMocks = TestMocksModule.TestMocks
    private typealias MockUserDefaults = TestMocks.MockUserDefaults
    private typealias MockFileManager = TestMocks.MockFileManager
    
    /// Test environment with test data
    private struct TestContext {
        let userDefaults: MockUserDefaults
        let fileManager: MockFileManager
        
        init() {
            userDefaults = MockUserDefaults()
            fileManager = MockFileManager()
        }
        
        func createConfiguration(
            id: UUID = UUID(),
            name: String = "Test Configuration",
            description: String? = nil,
            enabled: Bool = true,
            schedule: BackupSchedule? = nil,
            sources: [BackupSource] = [],
            excludedPaths: [String] = [],
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
    }
    
    // MARK: - Tests
    
    @Test("Test default values", ["configuration", "default"] as! TestTrait)
    func testDefaultValues() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating configuration with defaults
        let config = context.createConfiguration()
        
        // Then: Properties should match
        #expect(!config.id.uuidString.isEmpty)
        #expect(config.name == "Test Configuration")
        #expect(config.description == nil)
        #expect(config.enabled == true)
        #expect(config.schedule == nil)
        #expect(config.sources.isEmpty)
        #expect(config.excludedPaths.isEmpty)
        #expect(config.tags.isEmpty)
    }
    
    @Test("Test custom values", ["configuration", "custom"] as! TestTrait)
    func testCustomValues() throws {
        // Given: Test context and data
        let context = TestContext()
        let id = UUID()
        let name = "Custom Config"
        let desc = "Test description"
        let enabled = false
        let schedule = BackupSchedule(interval: .daily, time: Date())
        let sources = [
            BackupSource(path: "/path/1"),
            BackupSource(path: "/path/2")
        ]
        let excludedPaths = ["/exclude/1", "/exclude/2"]
        let tags = [BackupTag(name: "tag1"), BackupTag(name: "tag2")]
        
        // When: Creating configuration with custom values
        let config = context.createConfiguration(
            id: id,
            name: name,
            description: desc,
            enabled: enabled,
            schedule: schedule,
            sources: sources,
            excludedPaths: excludedPaths,
            tags: tags
        )
        
        // Then: Properties should match
        #expect(config.id == id)
        #expect(config.name == name)
        #expect(config.description == desc)
        #expect(config.enabled == enabled)
        #expect(config.schedule?.interval == schedule.interval)
        #expect(config.schedule?.time == schedule.time)
        #expect(config.sources == sources)
        #expect(config.excludedPaths == excludedPaths)
        #expect(config.tags == tags)
    }
    
    @Test("Test persistence", ["configuration", "persistence"] as! TestTrait)
    func testPersistence() throws {
        // Given: Test context and configuration
        let context = TestContext()
        let config = context.createConfiguration()
        
        // When: Saving and loading
        try config.save(to: context.userDefaults)
        let loaded = try BackupConfiguration.load(from: context.userDefaults, forId: config.id)
        
        // Then: Properties should match
        #expect(loaded?.id == config.id)
        #expect(loaded?.name == config.name)
        #expect(loaded?.description == config.description)
        #expect(loaded?.enabled == config.enabled)
        #expect(loaded?.schedule == config.schedule)
        #expect(loaded?.sources == config.sources)
        #expect(loaded?.excludedPaths == config.excludedPaths)
        #expect(loaded?.tags == config.tags)
    }
    
    @Test("Test edge cases", ["configuration", "edge"] as! TestTrait)
    func testEdgeCases() throws {
        // Given: Test context
        let context = TestContext()
        
        // Test empty configuration
        let emptyConfig = context.createConfiguration(
            name: "",
            description: "",
            enabled: false
        )
        
        // When: Saving and loading empty config
        try emptyConfig.save(to: context.userDefaults)
        let loaded = try BackupConfiguration.load(from: context.userDefaults, forId: emptyConfig.id)
        
        // Then: Properties should match
        #expect(loaded?.name == "")
        #expect(loaded?.description == "")
        #expect(loaded?.sources.isEmpty)
        #expect(loaded?.excludedPaths.isEmpty)
        #expect(loaded?.tags.isEmpty)
    }
}
