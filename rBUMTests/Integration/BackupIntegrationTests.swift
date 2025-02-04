//
//  BackupIntegrationTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 03/02/2025.
//

import XCTest
@testable import rBUM
@testable import Core

final class BackupIntegrationTests: XCTestCase {
    // MARK: - Properties
    private var backupService: ResticCommandService!
    private var securityService: DefaultSecurityService!
    private var mockLogger: MockLogger!
    private var mockXPCService: MockXPCService!
    private var mockKeychainService: MockKeychainService!
    private var mockBookmarkService: MockBookmarkService!
    private let fileManager = FileManager.default
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        mockXPCService = MockXPCService()
        mockKeychainService = MockKeychainService()
        mockBookmarkService = MockBookmarkService()
        
        securityService = DefaultSecurityService(
            logger: mockLogger,
            bookmarkService: mockBookmarkService,
            keychainService: mockKeychainService
        )
        
        backupService = ResticCommandService(
            logger: mockLogger,
            xpcService: mockXPCService,
            keychainService: mockKeychainService
        )
    }
    
    override func tearDown() {
        backupService = nil
        securityService = nil
        mockLogger.clear()
        mockXPCService.clear()
        mockKeychainService.clear()
        mockBookmarkService.clear()
        super.tearDown()
    }
    
    // MARK: - Helper Functions
    private func createTestDirectory(name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    private func createTestFile(in directory: URL, name: String, content: String) throws -> URL {
        let fileURL = directory.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    // MARK: - Integration Tests
    func testFullBackupWorkflow() async throws {
        // Given
        let sourceURL = try createTestDirectory(name: "test-source")
        let repoURL = try createTestDirectory(name: "test-repo")
        let restoreURL = try createTestDirectory(name: "test-restore")
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: repoURL)
            try? FileManager.default.removeItem(at: restoreURL)
        }
        
        // Create test files
        let testFile1 = try createTestFile(in: sourceURL, name: "test1.txt", content: "Test content 1")
        let testFile2 = try createTestFile(in: sourceURL, name: "test2.txt", content: "Test content 2")
        
        // Setup mocks
        mockKeychainService.hasValidCredentials = true
        mockBookmarkService.isValidBookmark = true
        mockBookmarkService.canStartAccessing = true
        mockXPCService.commandOutput = "repository initialized"
        
        // When - Initialize Repository
        try await backupService.initializeRepository(at: repoURL)
        XCTAssertTrue(mockLogger.containsMessage("Successfully initialized repository"))
        
        // When - Validate Access
        let hasAccess = try await securityService.validateAccess(to: sourceURL)
        XCTAssertTrue(hasAccess)
        XCTAssertTrue(mockLogger.containsMessage("Successfully validated access"))
        
        // When - Perform Backup
        mockXPCService.commandOutput = "snapshot abc123 saved"
        try await backupService.backup(source: sourceURL, to: repoURL)
        XCTAssertTrue(mockLogger.containsMessage("Successfully backed up files"))
        
        // When - List Snapshots
        mockXPCService.commandOutput = """
        {
            "snapshots": [
                {
                    "id": "abc123",
                    "time": "2025-02-04T09:32:54Z",
                    "paths": ["/test"]
                }
            ]
        }
        """
        let snapshots = try await backupService.listSnapshots(in: repoURL)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.id, "abc123")
        XCTAssertTrue(mockLogger.containsMessage("Successfully listed snapshots"))
        
        // When - Restore Files
        mockXPCService.commandOutput = "restored snapshot abc123"
        try await backupService.restore(from: repoURL, to: restoreURL, snapshot: "abc123")
        XCTAssertTrue(mockLogger.containsMessage("Successfully restored files"))
        
        // Then - Verify Restored Files
        let restoredFile1 = restoreURL.appendingPathComponent("test1.txt")
        let restoredFile2 = restoreURL.appendingPathComponent("test2.txt")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoredFile1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoredFile2.path))
    }
    
    func testBackupWorkflowWithFailures() async throws {
        // Given
        let sourceURL = try createTestDirectory(name: "test-source")
        let repoURL = try createTestDirectory(name: "test-repo")
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: repoURL)
        }
        
        // Create test file
        let testFile = try createTestFile(in: sourceURL, name: "test.txt", content: "Test content")
        
        // Test 1: Repository Initialization Failure
        mockXPCService.shouldFail = true
        await XCTAssertThrowsError(try await backupService.initializeRepository(at: repoURL)) { error in
            XCTAssertTrue(error is ResticError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to initialize repository"))
        }
        
        // Test 2: Access Validation Failure
        mockBookmarkService.isValidBookmark = false
        await XCTAssertThrowsError(try await securityService.validateAccess(to: sourceURL)) { error in
            XCTAssertTrue(error is SecurityError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to validate bookmark"))
        }
        
        // Test 3: Backup Failure
        mockBookmarkService.isValidBookmark = true
        mockXPCService.shouldFail = true
        await XCTAssertThrowsError(try await backupService.backup(source: sourceURL, to: repoURL)) { error in
            XCTAssertTrue(error is ResticError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to backup files"))
        }
        
        // Test 4: Missing Credentials
        mockKeychainService.hasValidCredentials = false
        await XCTAssertThrowsError(try await backupService.initializeRepository(at: repoURL)) { error in
            XCTAssertTrue(error is ResticError)
            XCTAssertTrue(mockLogger.containsMessage("Missing required credentials"))
        }
    }
    
    func testConcurrentBackupOperations() async throws {
        // Given
        let source1URL = try createTestDirectory(name: "test-source-1")
        let source2URL = try createTestDirectory(name: "test-source-2")
        let repo1URL = try createTestDirectory(name: "test-repo-1")
        let repo2URL = try createTestDirectory(name: "test-repo-2")
        defer {
            try? FileManager.default.removeItem(at: source1URL)
            try? FileManager.default.removeItem(at: source2URL)
            try? FileManager.default.removeItem(at: repo1URL)
            try? FileManager.default.removeItem(at: repo2URL)
        }
        
        // Create test files
        try createTestFile(in: source1URL, name: "test1.txt", content: "Test content 1")
        try createTestFile(in: source2URL, name: "test2.txt", content: "Test content 2")
        
        // Setup mocks
        mockKeychainService.hasValidCredentials = true
        mockBookmarkService.isValidBookmark = true
        mockBookmarkService.canStartAccessing = true
        mockXPCService.commandOutput = "repository initialized"
        
        // When - Run concurrent operations
        async let operation1 = backupService.initializeRepository(at: repo1URL)
        async let operation2 = backupService.initializeRepository(at: repo2URL)
        
        // Then
        try await [operation1, operation2]
        XCTAssertTrue(mockLogger.containsMessage("Successfully initialized repository"))
    }
    
    func testBackupWithLargeFiles() async throws {
        // Given
        let sourceURL = try createTestDirectory(name: "test-source-large")
        let repoURL = try createTestDirectory(name: "test-repo-large")
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: repoURL)
        }
        
        // Create a large test file (10MB)
        let largeContent = String(repeating: "A", count: 10 * 1024 * 1024)
        try createTestFile(in: sourceURL, name: "large-file.txt", content: largeContent)
        
        // Setup mocks
        mockKeychainService.hasValidCredentials = true
        mockBookmarkService.isValidBookmark = true
        mockBookmarkService.canStartAccessing = true
        mockXPCService.commandOutput = "repository initialized"
        
        // When
        try await backupService.initializeRepository(at: repoURL)
        
        mockXPCService.commandOutput = "snapshot abc123 saved"
        try await backupService.backup(source: sourceURL, to: repoURL)
        
        // Then
        XCTAssertTrue(mockLogger.containsMessage("Successfully backed up files"))
    }
}
