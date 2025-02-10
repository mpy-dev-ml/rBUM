import XCTest
@testable import Core
@testable import rBUM

extension DefaultSecurityServiceTests {
    // MARK: - Credential Management Tests

    func testCredentialPersistence() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-persistence")
        defer { cleanupTestURLs(testURL) }

        let credentials = RepositoryCredentials(password: "test-password")
        mockKeychainService.hasValidCredentials = true

        // When
        try await service.saveCredentials(credentials, for: testURL)
        let loadedCredentials = try await service.loadCredentials(for: testURL)

        // Then
        XCTAssertEqual(credentials.password, loadedCredentials.password)
        verifyLogMessages(
            mockLogger,
            contains: [
                "Successfully saved credentials",
                "Successfully loaded credentials",
            ]
        )
    }

    func testCredentialRemoval() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-removal")
        defer { cleanupTestURLs(testURL) }

        let credentials = RepositoryCredentials(password: "test-password")
        mockKeychainService.hasValidCredentials = true

        // When
        try await service.saveCredentials(credentials, for: testURL)
        try await service.removeCredentials(for: testURL)

        // Then
        await XCTAssertThrowsError(try service.loadCredentials(for: testURL)) { error in
            XCTAssertTrue(error is SecurityError)
        }
        verifyLogMessages(
            mockLogger,
            contains: [
                "Successfully removed credentials",
            ]
        )
    }
}
