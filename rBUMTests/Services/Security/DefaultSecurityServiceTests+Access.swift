import XCTest
@testable import Core
@testable import rBUM

extension DefaultSecurityServiceTests {
    // MARK: - Access Validation Tests

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
                "Successfully validated access",
            ]
        )
    }
}

extension DefaultSecurityServiceTests {
    func testValidateAccess() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-validate")
        defer { cleanupTestURLs(testURL) }

        // When
        try await securityService.validateAccess(to: testURL)

        // Then
        XCTAssertTrue(mockBookmarkService.validateAccessCalled)
        XCTAssertEqual(mockBookmarkService.validateAccessURL, testURL)
    }

    func testValidateAccessWithoutPermissions() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-no-perms")
        defer { cleanupTestURLs(testURL) }
        mockBookmarkService.validateAccessResult = false

        // When/Then
        await XCTAssertThrowsError(try securityService.validateAccess(to: testURL)) { error in
            XCTAssertTrue(error is SecurityError)
            if let securityError = error as? SecurityError {
                XCTAssertEqual(securityError, .accessDenied)
            }
        }
    }

    func testSecureResourceAccess() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-secure-access")
        defer { cleanupTestURLs(testURL) }

        // When
        try await securityService.secureResourceAccess(to: testURL)

        // Then
        XCTAssertTrue(mockBookmarkService.startAccessingCalled)
        XCTAssertEqual(mockBookmarkService.startAccessingURL, testURL)
    }

    func testConcurrentAccessValidation() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-concurrent")
        defer { cleanupTestURLs(testURL) }

        // When
        async let validation1 = securityService.validateAccess(to: testURL)
        async let validation2 = securityService.validateAccess(to: testURL)
        async let validation3 = securityService.validateAccess(to: testURL)

        // Then
        _ = try await [validation1, validation2, validation3]
        XCTAssertEqual(mockBookmarkService.validateAccessCallCount, 3)
    }
}
