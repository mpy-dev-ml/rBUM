//
//  DefaultRepositoryCreationServiceTests.swift
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

final class DefaultRepositoryCreationServiceTests: XCTestCase {
    // MARK: - Properties

    private var service: DefaultRepositoryCreationService!
    private var mockLogger: MockLogger!
    private var mockSecurityService: MockSecurityService!
    private var mockBookmarkService: MockBookmarkService!
    private var mockKeychainService: MockKeychainService!
    private let fileManager = FileManager.default

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        mockSecurityService = MockSecurityService()
        mockBookmarkService = MockBookmarkService()
        mockKeychainService = MockKeychainService()

        service = DefaultRepositoryCreationService(
            logger: mockLogger,
            securityService: mockSecurityService,
            bookmarkService: mockBookmarkService,
            keychainService: mockKeychainService
        )
    }

    override func tearDown() {
        service = nil
        mockLogger.clear()
        mockSecurityService.clear()
        mockBookmarkService.clear()
        mockKeychainService.clear()
        super.tearDown()
    }

    // MARK: - Tests

    func testCreateDefaultRepository() async throws {
        // Given
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let expectedURL = appSupport.appendingPathComponent("Repositories/Default", isDirectory: true)
        defer { cleanupTemporaryDirectory(expectedURL) }

        let testBookmark = Data("testBookmark".utf8)
        mockBookmarkService.bookmarkToReturn = testBookmark
        mockBookmarkService.canStartAccessing = true

        // When
        let repositoryURL = try await service.createDefaultRepository()

        // Then
        XCTAssertEqual(repositoryURL, expectedURL)
        XCTAssertTrue(fileManager.fileExists(atPath: repositoryURL.path))
        XCTAssertEqual(mockBookmarkService.bookmarkedURL, expectedURL)
        XCTAssertTrue(mockLogger.containsMessage("Created default repository"))
    }

    func testGetDefaultRepositoryLocation() async throws {
        // Given
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let repositoryURL = appSupport.appendingPathComponent("Repositories/Default", isDirectory: true)
        try fileManager.createDirectory(at: repositoryURL, withIntermediateDirectories: true)
        defer { cleanupTemporaryDirectory(repositoryURL) }

        mockBookmarkService.isValidBookmark = true
        mockSecurityService.hasAccess = true

        // When
        let foundURL = try await service.getDefaultRepositoryLocation()

        // Then
        XCTAssertEqual(foundURL, repositoryURL)
        XCTAssertTrue(mockLogger.containsMessage("Found default repository"))
    }

    func testGetDefaultRepositoryLocationWhenNotExists() async throws {
        // Given
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let repositoryURL = appSupport.appendingPathComponent("Repositories/Default", isDirectory: true)
        try? fileManager.removeItem(at: repositoryURL)

        // When
        let foundURL = try await service.getDefaultRepositoryLocation()

        // Then
        XCTAssertNil(foundURL)
        XCTAssertTrue(mockLogger.containsMessage("Default repository not found"))
    }

    func testValidateDefaultRepository() async throws {
        // Given
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let repositoryURL = appSupport.appendingPathComponent("Repositories/Default", isDirectory: true)
        try fileManager.createDirectory(at: repositoryURL, withIntermediateDirectories: true)
        defer { cleanupTemporaryDirectory(repositoryURL) }

        mockBookmarkService.isValidBookmark = true
        mockSecurityService.hasAccess = true

        // When
        let isValid = try await service.validateDefaultRepository()

        // Then
        XCTAssertTrue(isValid)
        XCTAssertTrue(mockLogger.containsMessage("Successfully validated default repository"))
    }

    func testHealthCheck() async {
        // Given
        mockBookmarkService.isHealthy = true
        mockKeychainService.isHealthy = true
        mockSecurityService.isHealthy = true

        // When
        let isHealthy = await service.performHealthCheck()

        // Then
        XCTAssertTrue(isHealthy)
        XCTAssertTrue(mockLogger.containsMessage("health check passed"))
    }

    func testHealthCheckFailsWithStuckOperations() async {
        // Given
        mockBookmarkService.isHealthy = true
        mockKeychainService.isHealthy = true
        mockSecurityService.isHealthy = true

        // Create a stuck operation
        _ = try? await service.createDefaultRepository()

        // When
        let isHealthy = await service.performHealthCheck()

        // Then
        XCTAssertFalse(isHealthy)
        XCTAssertTrue(mockLogger.containsMessage("potentially stuck operations"))
    }

    func testRepositoryCreationFailsWithoutAccess() async throws {
        // Given
        mockSecurityService.shouldFailValidation = true

        // When/Then
        await XCTAssertThrowsError(try service.createDefaultRepository()) { error in
            XCTAssertTrue(error is SecurityError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to create default repository"))
        }
    }

    func testRepositoryValidationFailsWithInvalidBookmark() async throws {
        // Given
        mockBookmarkService.isValidBookmark = false

        // When/Then
        await XCTAssertThrowsError(try service.validateDefaultRepository()) { error in
            XCTAssertTrue(error is BookmarkError)
            XCTAssertTrue(mockLogger.containsMessage("Failed to validate default repository"))
        }
    }
}

// MARK: - Mock Classes

private class MockBookmarkService: BookmarkServiceProtocol {
    var isHealthy: Bool = true
    var isValidBookmark: Bool = false
    var bookmarkedURL: URL?
    var bookmarkToReturn: Data?
    var canStartAccessing: Bool = false

    func createBookmark(for url: URL, readOnly _: Bool) async throws -> Data {
        bookmarkedURL = url
        return bookmarkToReturn ?? Data()
    }

    func resolveBookmark(_: Data) async throws -> URL {
        guard let url = bookmarkedURL else {
            throw BookmarkError.resolutionFailed("No URL")
        }
        return url
    }

    func startAccessing(_: URL) async throws -> Bool {
        canStartAccessing
    }

    func stopAccessing(_: URL) {}

    func validateBookmark(for _: URL) async throws -> Bool {
        isValidBookmark
    }

    func performHealthCheck() async -> Bool {
        isHealthy
    }

    func clear() {
        isHealthy = true
        isValidBookmark = false
        bookmarkedURL = nil
        bookmarkToReturn = nil
        canStartAccessing = false
    }
}

private class MockKeychainService: KeychainServiceProtocol {
    var isHealthy: Bool = true

    func storeCredentials(_: KeychainCredentials) throws {}

    func retrieveCredentials() throws -> KeychainCredentials {
        KeychainCredentials(repositoryUrl: URL(fileURLWithPath: "/test"), password: "test")
    }

    func deleteCredentials() throws {}

    func storeBookmark(_: Data, for _: URL) throws {}

    func retrieveBookmark(for _: URL) throws -> Data {
        Data()
    }

    func deleteBookmark(for _: URL) throws {}

    func storeGenericPassword(_: Data, service _: String, account _: String) throws {}

    func retrieveGenericPassword(service _: String, account _: String) throws -> Data {
        Data()
    }

    func deleteGenericPassword(service _: String, account _: String) throws {}

    func performHealthCheck() async -> Bool {
        isHealthy
    }

    func clear() {
        isHealthy = true
    }
}

private class MockSecurityService: SecurityServiceProtocol {
    var isHealthy: Bool = true
    var hasAccess: Bool = false
    var shouldFailValidation: Bool = false

    func validateAccess(to _: URL) async throws -> Bool {
        if shouldFailValidation {
            throw SecurityError.validationFailed("Validation failed")
        }
        return hasAccess
    }

    func performHealthCheck() async -> Bool {
        isHealthy
    }

    func clear() {
        isHealthy = true
        hasAccess = false
        shouldFailValidation = false
    }
}

private class MockLogger {
    var messages: [String] = []

    func log(_ message: String) {
        messages.append(message)
    }

    func containsMessage(_ message: String) -> Bool {
        messages.contains { $0.contains(message) }
    }

    func clear() {
        messages.removeAll()
    }
}

func cleanupTemporaryDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}
