//
//  KeychainServiceTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import XCTest
@testable import Core
@testable import rBUM

final class KeychainServiceTests: XCTestCase {
    // MARK: - Properties

    private var service: KeychainService!
    private var mockLogger: MockLogger!
    private let fileManager = FileManager.default

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        service = KeychainService(logger: mockLogger)

        // Clean up any test items that might have been left from previous runs
        try? service.deleteGenericPassword(service: "test-service", account: "test-account")
        try? service.deleteBookmark(for: URL(fileURLWithPath: "/test/path"))
    }

    override func tearDown() {
        // Clean up test items
        try? service.deleteGenericPassword(service: "test-service", account: "test-account")
        try? service.deleteBookmark(for: URL(fileURLWithPath: "/test/path"))

        service = nil
        mockLogger.clear()
        super.tearDown()
    }

    // MARK: - Generic Password Tests

    func testStoreAndRetrieveGenericPassword() throws {
        // Given
        let password = Data("test-password".utf8)
        let serviceName = "test-service"
        let accountName = "test-account"

        // When
        try service.storeGenericPassword(password, service: serviceName, account: accountName)
        let retrievedPassword = try service.retrieveGenericPassword(service: serviceName, account: accountName)

        // Then
        XCTAssertEqual(retrievedPassword, password)
        XCTAssertTrue(mockLogger.containsMessage("Successfully stored generic password"))
        XCTAssertTrue(mockLogger.containsMessage("Successfully retrieved generic password"))
    }

    func testDeleteGenericPassword() throws {
        // Given
        let password = Data("test-password".utf8)
        let serviceName = "test-service"
        let accountName = "test-account"

        // Store password first
        try service.storeGenericPassword(password, service: serviceName, account: accountName)

        // When
        try service.deleteGenericPassword(service: serviceName, account: accountName)

        // Then
        XCTAssertThrowsError(try service.retrieveGenericPassword(service: serviceName, account: accountName)) { error in
            XCTAssertTrue(error is KeychainError)
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
        XCTAssertTrue(mockLogger.containsMessage("Successfully deleted generic password"))
    }

    func testRetrieveNonexistentPassword() {
        // Given
        let serviceName = "nonexistent-service"
        let accountName = "nonexistent-account"

        // When/Then
        XCTAssertThrowsError(try service.retrieveGenericPassword(service: serviceName, account: accountName)) { error in
            XCTAssertTrue(error is KeychainError)
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
            XCTAssertTrue(mockLogger.containsMessage("Failed to retrieve generic password"))
        }
    }

    // MARK: - Bookmark Tests

    func testStoreAndRetrieveBookmark() throws {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        let bookmark = Data("test-bookmark".utf8)

        // When
        try service.storeBookmark(bookmark, for: testURL)
        let retrievedBookmark = try service.retrieveBookmark(for: testURL)

        // Then
        XCTAssertEqual(retrievedBookmark, bookmark)
        XCTAssertTrue(mockLogger.containsMessage("Successfully stored bookmark"))
        XCTAssertTrue(mockLogger.containsMessage("Successfully retrieved bookmark"))
    }

    func testDeleteBookmark() throws {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        let bookmark = Data("test-bookmark".utf8)

        // Store bookmark first
        try service.storeBookmark(bookmark, for: testURL)

        // When
        try service.deleteBookmark(for: testURL)

        // Then
        XCTAssertThrowsError(try service.retrieveBookmark(for: testURL)) { error in
            XCTAssertTrue(error is KeychainError)
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
        XCTAssertTrue(mockLogger.containsMessage("Successfully deleted bookmark"))
    }

    func testRetrieveNonexistentBookmark() {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent")

        // When/Then
        XCTAssertThrowsError(try service.retrieveBookmark(for: testURL)) { error in
            XCTAssertTrue(error is KeychainError)
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
            XCTAssertTrue(mockLogger.containsMessage("Failed to retrieve bookmark"))
        }
    }

    // MARK: - Health Check Tests

    func testHealthCheck() async {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        let bookmark = Data("test-bookmark".utf8)
        try? service.storeBookmark(bookmark, for: testURL)

        // When
        let isHealthy = await service.performHealthCheck()

        // Then
        XCTAssertTrue(isHealthy)
        XCTAssertTrue(mockLogger.containsMessage("Keychain service health check passed"))

        // Cleanup
        try? service.deleteBookmark(for: testURL)
    }

    func testHealthCheckWithInvalidKeychain() async {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        let bookmark = Data("test-bookmark".utf8)
        try? service.storeBookmark(bookmark, for: testURL)
        try? service.deleteBookmark(for: testURL)

        // When
        let isHealthy = await service.performHealthCheck()

        // Then
        XCTAssertTrue(isHealthy) // Should still be healthy even if items don't exist
        XCTAssertTrue(mockLogger.containsMessage("Keychain service health check passed"))
    }

    // MARK: - Error Handling Tests

    func testDuplicateItemError() {
        // Given
        let password = Data("test-password".utf8)
        let serviceName = "test-service"
        let accountName = "test-account"

        // When/Then
        // First store should succeed
        XCTAssertNoThrow(try service.storeGenericPassword(password, service: serviceName, account: accountName))

        // Second store should fail with duplicate error
        XCTAssertThrowsError(try service.storeGenericPassword(
            password,
            service: serviceName,
            account: accountName
        )) { error in
            XCTAssertTrue(error is KeychainError)
            XCTAssertEqual(error as? KeychainError, .duplicateItem)
            XCTAssertTrue(mockLogger.containsMessage("Failed to store generic password"))
        }
    }

    func testDeleteNonexistentItem() {
        // Given
        let serviceName = "nonexistent-service"
        let accountName = "nonexistent-account"

        // When/Then
        XCTAssertThrowsError(try service.deleteGenericPassword(service: serviceName, account: accountName)) { error in
            XCTAssertTrue(error is KeychainError)
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
            XCTAssertTrue(mockLogger.containsMessage("Failed to delete generic password"))
        }
    }
}
