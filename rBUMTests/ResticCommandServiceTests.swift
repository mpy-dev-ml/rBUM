//
//  ResticCommandServiceTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import XCTest
@testable import rBUM
@testable import Core

final class ResticCommandServiceTests: XCTestCase {
    // MARK: - Properties
    private var service: ResticCommandService!
    private var mockLogger: MockLogger!
    private var mockXPCService: MockXPCService!
    private var mockKeychainService: MockKeychainService!
    private let fileManager = FileManager.default
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        mockXPCService = MockXPCService()
        mockKeychainService = MockKeychainService()
        
        service = ResticCommandService(
            logger: mockLogger,
            xpcService: mockXPCService,
            keychainService: mockKeychainService
        )
    }
    
    override func tearDown() {
        service = nil
        mockLogger.clear()
        mockXPCService.clear()
        mockKeychainService.clear()
        super.tearDown()
    }
    
    // MARK: - Tests
    func testInitializeRepository() async throws {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-repo")
        try FileManager.default.createDirectory(at: testURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testURL) }
        
        mockXPCService.commandOutput = "repository initialized"
        mockKeychainService.hasValidCredentials = true
        
        // When
        try await service.initializeRepository(at: testURL)
        
        // Then
        XCTAssertTrue(mockXPCService.lastCommand?.contains("restic init") ?? false)
        XCTAssertTrue(mockLogger.containsMessage("Successfully initialized repository"))
    }
    
    func testInitializeRepositoryFailure() async {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-repo")
        mockXPCService.shouldFail = true
        mockKeychainService.hasValidCredentials = true
        
        // When/Then
        await XCTAssertThrowsError(try await service.initializeRepository(at: testURL)) { error in
            XCTAssertTrue(error is ResticError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to initialize repository"))
        }
    }
    
    func testBackupFiles() async throws {
        // Given
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("source")
        let repoURL = FileManager.default.temporaryDirectory.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: repoURL)
        }
        
        mockXPCService.commandOutput = "snapshot abc123 saved"
        mockKeychainService.hasValidCredentials = true
        
        // When
        try await service.backup(source: sourceURL, to: repoURL)
        
        // Then
        XCTAssertTrue(mockXPCService.lastCommand?.contains("restic backup") ?? false)
        XCTAssertTrue(mockLogger.containsMessage("Successfully backed up files"))
    }
    
    func testBackupFilesFailure() async {
        // Given
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("source")
        let repoURL = FileManager.default.temporaryDirectory.appendingPathComponent("repo")
        mockXPCService.shouldFail = true
        mockKeychainService.hasValidCredentials = true
        
        // When/Then
        await XCTAssertThrowsError(try await service.backup(source: sourceURL, to: repoURL)) { error in
            XCTAssertTrue(error is ResticError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to backup files"))
        }
    }
    
    func testRestoreFiles() async throws {
        // Given
        let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent("target")
        let repoURL = FileManager.default.temporaryDirectory.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: targetURL)
            try? FileManager.default.removeItem(at: repoURL)
        }
        
        mockXPCService.commandOutput = "restored snapshot abc123"
        mockKeychainService.hasValidCredentials = true
        
        // When
        try await service.restore(from: repoURL, to: targetURL, snapshot: "abc123")
        
        // Then
        XCTAssertTrue(mockXPCService.lastCommand?.contains("restic restore") ?? false)
        XCTAssertTrue(mockLogger.containsMessage("Successfully restored files"))
    }
    
    func testRestoreFilesFailure() async {
        // Given
        let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent("target")
        let repoURL = FileManager.default.temporaryDirectory.appendingPathComponent("repo")
        mockXPCService.shouldFail = true
        mockKeychainService.hasValidCredentials = true
        
        // When/Then
        await XCTAssertThrowsError(try await service.restore(from: repoURL, to: targetURL, snapshot: "abc123")) { error in
            XCTAssertTrue(error is ResticError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to restore files"))
        }
    }
    
    func testListSnapshots() async throws {
        // Given
        let repoURL = FileManager.default.temporaryDirectory.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repoURL) }
        
        mockXPCService.commandOutput = """
        {
            "snapshots": [
                {
                    "id": "abc123",
                    "time": "2025-02-04T09:24:45Z",
                    "paths": ["/test"]
                }
            ]
        }
        """
        mockKeychainService.hasValidCredentials = true
        
        // When
        let snapshots = try await service.listSnapshots(in: repoURL)
        
        // Then
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.id, "abc123")
        XCTAssertTrue(mockXPCService.lastCommand?.contains("restic snapshots") ?? false)
        XCTAssertTrue(mockLogger.containsMessage("Successfully listed snapshots"))
    }
    
    func testListSnapshotsFailure() async {
        // Given
        let repoURL = FileManager.default.temporaryDirectory.appendingPathComponent("repo")
        mockXPCService.shouldFail = true
        mockKeychainService.hasValidCredentials = true
        
        // When/Then
        await XCTAssertThrowsError(try await service.listSnapshots(in: repoURL)) { error in
            XCTAssertTrue(error is ResticError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to list snapshots"))
        }
    }
    
    func testHealthCheck() async {
        // Given
        mockXPCService.isHealthy = true
        mockKeychainService.isHealthy = true
        
        // When
        let isHealthy = await service.performHealthCheck()
        
        // Then
        XCTAssertTrue(isHealthy)
        XCTAssertTrue(mockLogger.containsMessage("Restic command service health check passed"))
    }
    
    func testHealthCheckFailure() async {
        // Given
        mockXPCService.isHealthy = false
        mockKeychainService.isHealthy = true
        
        // When
        let isHealthy = await service.performHealthCheck()
        
        // Then
        XCTAssertFalse(isHealthy)
        XCTAssertTrue(mockLogger.containsMessage("Restic command service health check failed"))
    }
    
    func testInvalidRepositoryURL() async {
        // Given
        let invalidURL = URL(string: "")!
        
        // When/Then
        await XCTAssertThrowsError(try await service.initializeRepository(at: invalidURL)) { error in
            XCTAssertTrue(error is ResticError)
            XCTAssertTrue(mockLogger.containsMessage("Invalid repository URL"))
        }
    }
    
    func testMissingCredentials() async {
        // Given
        let repoURL = FileManager.default.temporaryDirectory.appendingPathComponent("repo")
        mockKeychainService.hasValidCredentials = false
        
        // When/Then
        await XCTAssertThrowsError(try await service.initializeRepository(at: repoURL)) { error in
            XCTAssertTrue(error is ResticError)
            XCTAssertTrue(mockLogger.containsMessage("Missing required credentials"))
        }
    }
}

// MARK: - Mock Classes
private class MockLogger: LoggerProtocol {
    var messages: [String] = []
    
    func debug(_ message: String, metadata: [String : LogMetadataValue]?, privacy: LogPrivacy, file: String, function: String, line: Int) {
        messages.append(message)
    }
    
    func info(_ message: String, metadata: [String : LogMetadataValue]?, privacy: LogPrivacy, file: String, function: String, line: Int) {
        messages.append(message)
    }
    
    func warning(_ message: String, metadata: [String : LogMetadataValue]?, privacy: LogPrivacy, file: String, function: String, line: Int) {
        messages.append(message)
    }
    
    func error(_ message: String, metadata: [String : LogMetadataValue]?, privacy: LogPrivacy, file: String, function: String, line: Int) {
        messages.append(message)
    }
    
    func clear() {
        messages.removeAll()
    }
    
    func containsMessage(_ message: String) -> Bool {
        return messages.contains { $0.contains(message) }
    }
}

private class MockXPCService: ResticXPCServiceProtocol {
    var isHealthy: Bool = true
    var lastCommand: String?
    var commandOutput: String = ""
    var shouldFail: Bool = false
    
    func initializeRepository(at path: String, password: String) async throws {
        lastCommand = "restic init \(path) \(password)"
        if shouldFail {
            throw XPCError.commandFailed("Failed to initialize repository")
        } else {
            return commandOutput
        }
    }
    
    func backup(source: String, to repository: String, password: String) async throws {
        lastCommand = "restic backup \(source) \(repository) \(password)"
        if shouldFail {
            throw XPCError.commandFailed("Failed to backup files")
        } else {
            return commandOutput
        }
    }
    
    func listSnapshots(in repository: String, password: String) async throws -> [Snapshot] {
        lastCommand = "restic snapshots \(repository) \(password)"
        if shouldFail {
            throw XPCError.commandFailed("Failed to list snapshots")
        } else {
            // Parse JSON output
            let data = Data(commandOutput.utf8)
            let json = try! JSONSerialization.jsonObject(with: data, options: [])
            let snapshots = json as! [[String: String]]
            return snapshots.map { Snapshot(id: $0["id"]!, timestamp: Date(), paths: [$0["paths"]!]) }
        }
    }
    
    func restore(from repository: String, to destination: String, snapshot: String, password: String) async throws {
        lastCommand = "restic restore \(repository) \(destination) \(snapshot) \(password)"
        if shouldFail {
            throw XPCError.commandFailed("Failed to restore files")
        } else {
            return commandOutput
        }
    }
    
    func performHealthCheck() async -> Bool {
        return isHealthy
    }
    
    func clear() {
        lastCommand = nil
        commandOutput = ""
        shouldFail = false
    }
}

private class MockKeychainService: KeychainServiceProtocol {
    var isHealthy: Bool = true
    var hasValidCredentials: Bool = true
    
    func getCredentials(for url: URL) async throws -> Credentials {
        if hasValidCredentials {
            return Credentials(username: "test", password: "test")
        } else {
            throw KeychainError.missingCredentials
        }
    }
    
    func storeCredentials(_ credentials: Credentials, for url: URL) async throws {}
    
    func deleteCredentials(for url: URL) async throws {}
    
    func performHealthCheck() async -> Bool {
        return isHealthy
    }
    
    func clear() {}
}
