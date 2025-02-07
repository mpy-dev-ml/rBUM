@testable import Core
@testable import rBUM
import XCTest

extension DefaultSecurityServiceTests {
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
                "Successfully loaded credentials"
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
                "Successfully removed credentials"
            ]
        )
    }
}
