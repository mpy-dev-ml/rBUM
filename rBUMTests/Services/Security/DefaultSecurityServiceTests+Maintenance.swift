@testable import Core
@testable import rBUM
import XCTest

extension DefaultSecurityServiceTests {
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

    func testResourceCleanupWithFailures() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-cleanup-failure")
        defer { cleanupTestURLs(testURL) }

        mockBookmarkService.isValidBookmark = true
        mockBookmarkService.canStartAccessing = true
        mockBookmarkService.shouldFailCleanup = true

        // When/Then
        await XCTAssertThrowsError(try service.cleanupResources()) { error in
            XCTAssertTrue(error is SecurityError)
        }
        verifyLogMessages(
            mockLogger,
            contains: [
                "Failed to clean up resources"
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

    func testHealthCheckWithPartialFailure() async {
        // Given
        mockBookmarkService.isHealthy = true
        mockKeychainService.isHealthy = false

        // When
        let isHealthy = await service.performHealthCheck()

        // Then
        XCTAssertFalse(isHealthy)
        verifyLogMessages(
            mockLogger,
            contains: [
                "Health check failed",
                "Keychain service health check failed"
            ]
        )
    }
}
