import XCTest
@testable import rBUM
@testable import Core

final class ResticXPCServiceTests: XCTestCase {
    // MARK: - Properties
    private var service: ResticXPCService!
    private var mockLogger: MockLogger!
    private let fileManager = FileManager.default
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        service = ResticXPCService(logger: mockLogger)
    }
    
    override func tearDown() {
        service = nil
        mockLogger.clear()
        super.tearDown()
    }
    
    // MARK: - Test Properties
    private let testPath = "/test/repository"
    private let testPassword = "test-password"
    
    // MARK: - Helper Functions
    private func createTemporaryDirectory() throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        return tempURL
    }
    
    // MARK: - Repository Tests
    func testInitializeRepository() async throws {
        // Given
        let repoURL = try createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }
        
        // When
        let output = try await service.initializeRepository(at: repoURL.path, password: testPassword)
        
        // Then
        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(mockLogger.containsMessage("Successfully initialized repository"))
    }
    
    func testInitializeRepositoryFailure() async {
        // Given
        let invalidPath = "/nonexistent/path"
        
        // When/Then
        await XCTAssertThrowsError(try await service.initializeRepository(at: invalidPath, password: testPassword)) { error in
            XCTAssertTrue(error is XPCError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to initialize repository"))
        }
    }
    
    // MARK: - Backup Tests
    func testBackup() async throws {
        // Given
        let sourceURL = try createTemporaryDirectory()
        let repoURL = try createTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: repoURL)
        }
        
        // Create a test file
        let testFile = sourceURL.appendingPathComponent("test.txt")
        try "test data".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Initialize repository
        _ = try await service.initializeRepository(at: repoURL.path, password: testPassword)
        
        // When
        let output = try await service.backup(source: sourceURL.path, repository: repoURL.path, password: testPassword)
        
        // Then
        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(mockLogger.containsMessage("Successfully executed backup command"))
    }
    
    func testBackupFailure() async {
        // Given
        let invalidSource = "/nonexistent/source"
        let invalidRepo = "/nonexistent/repo"
        
        // When/Then
        await XCTAssertThrowsError(try await service.backup(source: invalidSource, repository: invalidRepo, password: testPassword)) { error in
            XCTAssertTrue(error is XPCError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to execute backup command"))
        }
    }
    
    // MARK: - Restore Tests
    func testRestore() async throws {
        // Given
        let sourceURL = try createTemporaryDirectory()
        let repoURL = try createTemporaryDirectory()
        let restoreURL = try createTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: repoURL)
            try? FileManager.default.removeItem(at: restoreURL)
        }
        
        // Create and backup a test file
        let testFile = sourceURL.appendingPathComponent("test.txt")
        try "test data".write(to: testFile, atomically: true, encoding: .utf8)
        
        _ = try await service.initializeRepository(at: repoURL.path, password: testPassword)
        let backupOutput = try await service.backup(source: sourceURL.path, repository: repoURL.path, password: testPassword)
        
        // Get snapshot ID
        let snapshotId = try await extractLatestSnapshotId(repository: repoURL.path)
        
        // When
        let output = try await service.restore(repository: repoURL.path, destination: restoreURL.path, snapshot: snapshotId, password: testPassword)
        
        // Then
        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(mockLogger.containsMessage("Successfully executed restore command"))
        
        // Verify restored file
        let restoredFile = restoreURL.appendingPathComponent("test.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoredFile.path))
        let restoredData = try String(contentsOf: restoredFile, encoding: .utf8)
        XCTAssertEqual(restoredData, "test data")
    }
    
    func testRestoreFailure() async {
        // Given
        let invalidRepo = "/nonexistent/repo"
        let invalidDest = "/nonexistent/dest"
        let invalidSnapshot = "invalid-snapshot"
        
        // When/Then
        await XCTAssertThrowsError(try await service.restore(repository: invalidRepo, destination: invalidDest, snapshot: invalidSnapshot, password: testPassword)) { error in
            XCTAssertTrue(error is XPCError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to execute restore command"))
        }
    }
    
    // MARK: - Snapshot Tests
    func testListSnapshots() async throws {
        // Given
        let sourceURL = try createTemporaryDirectory()
        let repoURL = try createTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: repoURL)
        }
        
        // Create and backup a test file
        let testFile = sourceURL.appendingPathComponent("test.txt")
        try "test data".write(to: testFile, atomically: true, encoding: .utf8)
        
        _ = try await service.initializeRepository(at: repoURL.path, password: testPassword)
        _ = try await service.backup(source: sourceURL.path, repository: repoURL.path, password: testPassword)
        
        // When
        let output = try await service.listSnapshots(repository: repoURL.path, password: testPassword)
        
        // Then
        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(mockLogger.containsMessage("Successfully executed snapshots command"))
    }
    
    func testListSnapshotsFailure() async {
        // Given
        let invalidRepo = "/nonexistent/repo"
        
        // When/Then
        await XCTAssertThrowsError(try await service.listSnapshots(repository: invalidRepo, password: testPassword)) { error in
            XCTAssertTrue(error is XPCError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to execute snapshots command"))
        }
    }
    
    // MARK: - Health Check Tests
    func testHealthCheck() async {
        // When
        let isHealthy = await service.performHealthCheck()
        
        // Then
        XCTAssertTrue(isHealthy)
        XCTAssertTrue(mockLogger.containsMessage("XPC service health check passed"))
    }
    
    // MARK: - Helper Functions
    private func extractLatestSnapshotId(repository: String) async throws -> String {
        let snapshotsOutput = try await service.listSnapshots(repository: repository, password: testPassword)
        guard let snapshotId = snapshotsOutput.components(separatedBy: .newlines)
            .first(where: { $0.contains("snapshot") })?
            .components(separatedBy: .whitespaces)
            .first(where: { $0.count == 8 }) else {
            throw XPCError.commandFailed("Failed to extract snapshot ID")
        }
        return snapshotId
    }
}
