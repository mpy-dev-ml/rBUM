@testable import Core
import XCTest

final class BackupConfigurationServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var testSourceURL1: URL!
    private var testSourceURL2: URL!
    private var service: BackupConfigurationService!
    private var mockLogger: MockLogger!
    private var mockFileManager: MockFileManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temporary test directories
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        
        // Create test source directories
        testSourceURL1 = temporaryDirectory.appendingPathComponent("source1", isDirectory: true)
        try FileManager.default.createDirectory(at: testSourceURL1, withIntermediateDirectories: true)
        
        testSourceURL2 = temporaryDirectory.appendingPathComponent("source2", isDirectory: true)
        try FileManager.default.createDirectory(at: testSourceURL2, withIntermediateDirectories: true)
        
        // Set up mocks
        mockLogger = MockLogger()
        mockFileManager = MockFileManager()
        
        // Create service
        service = BackupConfigurationService(
            logger: mockLogger,
            fileManager: mockFileManager
        )
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        
        // Clean up temporary directory
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        
        temporaryDirectory = nil
        testSourceURL1 = nil
        testSourceURL2 = nil
        service = nil
        mockLogger = nil
        mockFileManager = nil
    }
    
    func testCreateConfiguration() async throws {
        // Given source URLs and configuration details
        let sources = [testSourceURL1, testSourceURL2]
        let name = "Test Backup"
        let description = "Test backup configuration"
        
        // When creating a configuration
        let config = try await service.createConfiguration(
            name: name,
            description: description,
            sources: sources
        )
        
        // Then it should be created correctly
        XCTAssertEqual(config.name, name)
        XCTAssertEqual(config.description, description)
        XCTAssertEqual(config.sources, sources)
        XCTAssertTrue(config.enabled)
        XCTAssertFalse(config.includeHidden)
        XCTAssertTrue(config.verifyAfterBackup)
        XCTAssertNil(config.repository)
        XCTAssertFalse(config.isAccessing)
        
        // And it should be retrievable
        let configs = await service.getConfigurations()
        XCTAssertEqual(configs.count, 1)
        XCTAssertEqual(configs.first?.id, config.id)
    }
    
    func testGetConfiguration() async throws {
        // Given a created configuration
        let config = try await service.createConfiguration(
            name: "Test Backup",
            sources: [testSourceURL1]
        )
        
        // When retrieving the configuration
        let retrieved = try await service.getConfiguration(id: config.id)
        
        // Then it should match the created configuration
        XCTAssertEqual(retrieved.id, config.id)
        XCTAssertEqual(retrieved.name, config.name)
        XCTAssertEqual(retrieved.sources, config.sources)
    }
    
    func testGetNonexistentConfiguration() async {
        // Given a non-existent configuration ID
        let id = UUID()
        
        // When trying to retrieve the configuration
        // Then it should throw an error
        await XCTAssertThrowsError(try await service.getConfiguration(id: id)) { error in
            XCTAssertTrue(error is BackupConfigurationError)
            if case .configurationNotFound(let errorId) = error as? BackupConfigurationError {
                XCTAssertEqual(errorId, id)
            }
        }
    }
    
    func testAccessLifecycle() async throws {
        // Given a created configuration
        let config = try await service.createConfiguration(
            name: "Test Backup",
            sources: [testSourceURL1]
        )
        
        // When starting access
        try await service.startAccessing(configurationId: config.id)
        
        // Then the configuration should be accessing
        let accessing = try await service.getConfiguration(id: config.id)
        XCTAssertTrue(accessing.isAccessing)
        
        // When stopping access
        await service.stopAccessing(configurationId: config.id)
        
        // Then the configuration should not be accessing
        let notAccessing = try await service.getConfiguration(id: config.id)
        XCTAssertFalse(notAccessing.isAccessing)
    }
}

// MARK: - Mock Types

private final class MockLogger: LoggerProtocol {
    func debug(_ message: String, privacy: PrivacyLevel) {}
    func info(_ message: String, privacy: PrivacyLevel) {}
    func warning(_ message: String, privacy: PrivacyLevel) {}
    func error(_ message: String, privacy: PrivacyLevel) {}
}

private final class MockFileManager: FileManagerProtocol {
    func fileExists(atPath path: String) -> Bool { true }
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {}
    func removeItem(at url: URL) throws {}
    func copyItem(at srcURL: URL, to dstURL: URL) throws {}
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?) throws -> [URL] {
        []
    }
}
