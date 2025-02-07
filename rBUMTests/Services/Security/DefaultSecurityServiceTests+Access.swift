@testable import Core
@testable import rBUM
import XCTest

extension DefaultSecurityServiceTests {
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
        verifyLogMessages(
            mockLogger,
            contains: [
                "Successfully validated access"
            ]
        )
    }

    func testAccessValidationWithExpiredBookmark() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-expired")
        defer { cleanupTestURLs(testURL) }

        mockBookmarkService.isValidBookmark = false
        mockBookmarkService.canStartAccessing = true
        mockBookmarkService.shouldRefreshBookmark = true

        // When
        let hasAccess = try await service.validateAccess(to: testURL)

        // Then
        XCTAssertTrue(hasAccess)
        verifyLogMessages(
            mockLogger,
            contains: [
                "Refreshing expired bookmark",
                "Successfully validated access"
            ]
        )
    }
}
