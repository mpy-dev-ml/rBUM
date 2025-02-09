@testable import Core
import XCTest

final class BackupConfigurationStorageTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var testSourceURL: URL!
    private var storage: BackupConfigurationStorage!
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
        
        // Create test source directory
        testSourceURL = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: testSourceURL, withIntermediateDirectories: true)
        
        // Set up mocks
        mockLogger = MockLogger()
        mockFileManager = MockFileManager(temporaryDirectory: temporaryDirectory)
        
        // Create storage
        storage = try BackupConfigurationStorage(
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
        testSourceURL = nil
        storage = nil
        mockLogger = nil
        mockFileManager = nil
    }
    
    func testSaveAndLoadConfigurations() async throws {
        // Given some backup configurations
        let config1 = try BackupConfiguration(
            name: "Test Backup 1",
            sources: [testSourceURL]
        )
        
        let config2 = try BackupConfiguration(
            name: "Test Backup 2",
            description: "Second test backup",
            sources: [testSourceURL]
        )
        
        let configurations = [config1, config2]
        
        // When saving the configurations
        try await storage.saveConfigurations(configurations)
        
        // And loading them back
        let loaded = try await storage.loadConfigurations()
        
        // Then they should match the original configurations
        XCTAssertEqual(loaded.count, configurations.count)
        XCTAssertEqual(loaded[0].id, configurations[0].id)
        XCTAssertEqual(loaded[0].name, configurations[0].name)
        XCTAssertEqual(loaded[0].sources, configurations[0].sources)
        XCTAssertEqual(loaded[1].id, configurations[1].id)
        XCTAssertEqual(loaded[1].name, configurations[1].name)
        XCTAssertEqual(loaded[1].description, configurations[1].description)
        XCTAssertEqual(loaded[1].sources, configurations[1].sources)
    }
    
    func testLoadEmptyConfigurations() async throws {
        // When loading configurations with no saved data
        let configurations = try await storage.loadConfigurations()
        
        // Then it should return an empty array
        XCTAssertTrue(configurations.isEmpty)
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
    private let temporaryDirectory: URL
    private var files: [String: Data] = [:]
    
    init(temporaryDirectory: URL) {
        self.temporaryDirectory = temporaryDirectory
    }
    
    func url(
        for directory: FileManager.SearchPathDirectory,
        in domain: FileManager.SearchPathDomainMask,
        appropriateFor url: URL?,
        create shouldCreate: Bool
    ) throws -> URL {
        return temporaryDirectory
    }
    
    func fileExists(atPath path: String) -> Bool {
        return files[path] != nil
    }
    
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {}
    
    func removeItem(at url: URL) throws {
        files.removeValue(forKey: url.path)
    }
    
    func copyItem(at srcURL: URL, to dstURL: URL) throws {}
    
    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?
    ) throws -> [URL] {
        return []
    }
}
