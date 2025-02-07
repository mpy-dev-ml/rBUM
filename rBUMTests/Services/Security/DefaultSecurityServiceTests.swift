//
//  DefaultSecurityServiceTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
@testable import Core
@testable import rBUM
import XCTest

final class DefaultSecurityServiceTests: XCTestCase {
    // MARK: - Properties

    private var service: DefaultSecurityService!
    private var mockLogger: MockLogger!
    private var mockBookmarkService: MockBookmarkService!
    private var mockKeychainService: MockKeychainService!
    private let fileManager = FileManager.default

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        mockBookmarkService = MockBookmarkService()
        mockKeychainService = MockKeychainService()

        service = DefaultSecurityService(
            logger: mockLogger,
            bookmarkService: mockBookmarkService,
            keychainService: mockKeychainService
        )
    }

    override func tearDown() {
        service = nil
        mockLogger.clear()
        mockBookmarkService.clear()
        mockKeychainService.clear()
        super.tearDown()
    }

    // MARK: - Test Setup Helpers

    private func setupTestEnvironment() throws {
        try setupTestDirectories()
        try setupTestFiles()
        setupMockServices()
    }

    private func setupTestDirectories() throws {
        let testURL = try URL.temporaryTestDirectory(name: "test-access")
        defer { cleanupTestURLs(testURL) }

        // Create test subdirectories
        let sourceDirectory = testURL.appendingPathComponent("source")
        let destinationDirectory = testURL.appendingPathComponent("destination")

        try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
    }

    private func setupTestFiles() throws {
        // Create test files with different permissions
        let testURL = try URL.temporaryTestDirectory(name: "test-access")
        defer { cleanupTestURLs(testURL) }

        try createTestFile(named: "readable.txt", permissions: [.readable], at: testURL)
        try createTestFile(named: "writable.txt", permissions: [.writable], at: testURL)
        try createTestFile(named: "executable.txt", permissions: [.executable], at: testURL)
        try createTestFile(named: "full-access.txt", permissions: [.readable, .writable, .executable], at: testURL)
    }

    private func setupMockServices() {
        mockBookmarkService = MockBookmarkService()
        mockKeychainService = MockKeychainService()
        mockLogger = MockLogger()

        configureBookmarkServiceMock()
        configureKeychainMock()
    }

    // MARK: - Test File Helpers

    private func createTestFile(named name: String, permissions: Set<FilePermission>, at url: URL) throws {
        let filePath = url.appendingPathComponent(name)
        try "Test content".write(to: filePath, atomically: true, encoding: .utf8)

        // Set file permissions
        var attributes: [FileAttributeKey: Any] = [:]
        if permissions.contains(.readable) {
            attributes[.posixPermissions] = 0o444
        }
        if permissions.contains(.writable) {
            attributes[.posixPermissions] = 0o222
        }
        if permissions.contains(.executable) {
            attributes[.posixPermissions] = 0o111
        }
        try fileManager.setAttributes(attributes, ofItemAtPath: filePath.path)
    }

    private func createSecurityScopedURL(for url: URL) throws -> URL {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        var isStale = false
        let securityScopedURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        return securityScopedURL
    }

    // MARK: - Mock Configuration Helpers

    private func configureBookmarkServiceMock() {
        mockBookmarkService.createBookmarkHandler = { url in
            try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        mockBookmarkService.resolveBookmarkHandler = { data in
            var isStale = false
            return try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }
    }

    private func configureKeychainMock() {
        mockKeychainService.saveHandler = { _, _, _ in
            // Simulate successful keychain save
            return true
        }

        mockKeychainService.loadHandler = { _, _ in
            // Return test data
            return Data("test-data".utf8)
        }
    }

    // MARK: - Verification Helpers

    private func verifySecurityAccess(for url: URL) throws {
        let hasAccess = try service.validateAccess(to: url)
        XCTAssertTrue(hasAccess, "Should have access to \(url.path)")

        let operations = service.getOperations(for: url)
        XCTAssertFalse(operations.isEmpty, "Should have recorded security operations")

        let lastOperation = operations.last
        XCTAssertEqual(lastOperation?.status, .success, "Last operation should be successful")
    }

    private func verifySecurityDenied(for url: URL) throws {
        let hasAccess = try service.validateAccess(to: url)
        XCTAssertFalse(hasAccess, "Should not have access to \(url.path)")

        let operations = service.getOperations(for: url)
        XCTAssertFalse(operations.isEmpty, "Should have recorded security operations")

        let lastOperation = operations.last
        XCTAssertEqual(lastOperation?.status, .failure, "Last operation should be failure")
    }

    private func verifyBookmarkCreation(for url: URL) throws {
        let bookmark = try service.createBookmark(for: url)
        XCTAssertNotNil(bookmark, "Should create bookmark")

        let operations = service.getOperations(for: url)
        let bookmarkOperations = operations.filter { $0.type == .createBookmark }
        XCTAssertFalse(bookmarkOperations.isEmpty, "Should have recorded bookmark creation")
    }

    // MARK: - Access Validation Tests

    func testValidateAccess() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-access")
        defer { cleanupTestURLs(testURL) }

        mockBookmarkService.isValidBookmark = true
        mockBookmarkService.canStartAccessing = true

        // When
        let hasAccess = try await service.validateAccess(to: testURL)

        // Then
        XCTAssertTrue(hasAccess)
        verifyLogMessages(
            mockLogger,
            contains: [
                "Successfully validated access"
            ]
        )
    }

    func testValidateAccessWithoutPermissions() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-no-access")
        defer { cleanupTestURLs(testURL) }

        mockBookmarkService.isValidBookmark = false
        mockBookmarkService.canStartAccessing = false

        // When/Then
        await XCTAssertThrowsError(try service.validateAccess(to: testURL)) { error in
            XCTAssertTrue(error is SecurityError)
        }
        verifyLogMessages(
            mockLogger,
            contains: [
                "Failed to validate access"
            ]
        )
    }

    // MARK: - Credential Management Tests

    func testSaveAndValidateCredentials() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-credentials")
        defer { cleanupTestURLs(testURL) }

        let credentials = RepositoryCredentials(password: "test-password")
        mockKeychainService.hasValidCredentials = true

        // When
        try await service.saveCredentials(credentials, for: testURL)
        let isValid = try await service.validateCredentials(for: testURL)

        // Then
        XCTAssertTrue(isValid)
        verifyLogMessages(
            mockLogger,
            contains: [
                "Successfully saved credentials",
                "Successfully validated credentials"
            ]
        )
    }

    func testInvalidCredentials() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-invalid-creds")
        defer { cleanupTestURLs(testURL) }

        mockKeychainService.hasValidCredentials = false

        // When/Then
        await XCTAssertThrowsError(try service.validateCredentials(for: testURL)) { error in
            XCTAssertTrue(error is SecurityError)
        }
        verifyLogMessages(
            mockLogger,
            contains: [
                "Failed to validate credentials"
            ]
        )
    }

    func testValidateCredentials() async throws {
        let url = URL(fileURLWithPath: "/test/path")
        let credentials = RepositoryCredentials(
            repositoryPath: "/test/path",
            password: "test-password"
        )

        try await service.validateCredentials(credentials, for: url)

        verifyLogMessages(
            mockLogger,
            contains: [
                "Successfully validated credentials"
            ]
        )
    }

    // MARK: - Resource Access Tests

    func testSecureResourceAccess() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-secure-access")
        defer { cleanupTestURLs(testURL) }

        mockBookmarkService.isValidBookmark = true
        mockBookmarkService.canStartAccessing = true
        mockKeychainService.hasValidCredentials = true

        // When
        let hasAccess = try await service.validateAccess(to: testURL)
        let hasCredentials = try await service.validateCredentials(for: testURL)

        // Then
        XCTAssertTrue(hasAccess)
        XCTAssertTrue(hasCredentials)
        verifyLogMessages(
            mockLogger,
            contains: [
                "Successfully validated access",
                "Successfully validated credentials"
            ]
        )
    }

    func testConcurrentAccessValidation() async throws {
        // Given
        let testURL1 = try URL.temporaryTestDirectory(name: "test-concurrent-1")
        let testURL2 = try URL.temporaryTestDirectory(name: "test-concurrent-2")
        defer {
            cleanupTestURLs(testURL1, testURL2)
        }

        mockBookmarkService.isValidBookmark = true
        mockBookmarkService.canStartAccessing = true

        // When
        async let validation1 = service.validateAccess(to: testURL1)
        async let validation2 = service.validateAccess(to: testURL2)

        // Then
        let (result1, result2) = try await (validation1, validation2)
        XCTAssertTrue(result1)
        XCTAssertTrue(result2)
    }

    // MARK: - Cleanup Tests

    func testResourceCleanup() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-cleanup")
        defer { cleanupTestURLs(testURL) }

        mockBookmarkService.isValidBookmark = true
        mockBookmarkService.canStartAccessing = true

        // When
        try await service.validateAccess(to: testURL)
        try await service.cleanupResources()

        // Then
        verifyLogMessages(
            mockLogger,
            contains: [
                "Successfully cleaned up resources"
            ]
        )
    }

    // MARK: - Health Check Tests

    func testHealthCheck() async {
        // Given
        mockBookmarkService.isHealthy = true
        mockKeychainService.isHealthy = true

        // When
        let isHealthy = await service.performHealthCheck()

        // Then
        XCTAssertTrue(isHealthy)
        verifyLogMessages(
            mockLogger,
            contains: [
                "Health check completed successfully"
            ]
        )
    }

    func testHealthCheckFailure() async {
        // Given
        mockBookmarkService.isHealthy = false
        mockKeychainService.isHealthy = true

        // When
        let isHealthy = await service.performHealthCheck()

        // Then
        XCTAssertFalse(isHealthy)
        verifyLogMessages(
            mockLogger,
            contains: [
                "Health check failed"
            ]
        )
    }
}
