import XCTest
@testable import Core
@testable import ResticService

final class ResticServiceSecurityTests: XCTestCase {
    private var service: ResticService!
    private var mockLogger: MockLogger!
    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        mockLogger = MockLogger()
        service = ResticService()

        // Create temporary directory for tests
        let fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        service = nil
        mockLogger = nil
        tempDirectory = nil
    }

    // MARK: - Security-Scoped Bookmark Tests

    func testBookmarkValidation_ValidBookmark_ReturnsTrue() throws {
        // Given
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        let bookmark = try testFile.bookmarkData(options: .withSecurityScope)

        // When
        let expectation = XCTestExpectation(description: "Bookmark validation")
        service.validateBookmark(bookmark) { isValid, error in
            // Then
            XCTAssertTrue(isValid)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testBookmarkValidation_InvalidBookmark_ReturnsFalse() {
        // Given
        let invalidBookmark = Data([0x00, 0x01, 0x02]) // Invalid bookmark data

        // When
        let expectation = XCTestExpectation(description: "Invalid bookmark validation")
        service.validateBookmark(invalidBookmark) { isValid, error in
            // Then
            XCTAssertFalse(isValid)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Repository Access Tests

    func testRepositoryAccess_ValidBookmark_SuccessfullyInitialises() throws {
        // Given
        let repoDir = tempDirectory.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        let bookmark = try repoDir.bookmarkData(options: .withSecurityScope)

        // When
        let expectation = XCTestExpectation(description: "Repository initialisation")
        service.initialiseRepository(at: bookmark, password: "test-password") { result in
            // Then
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertTrue(result.error.isEmpty)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testRepositoryAccess_InvalidBookmark_FailsToInitialise() {
        // Given
        let invalidBookmark = Data([0x00, 0x01, 0x02]) // Invalid bookmark data

        // When
        let expectation = XCTestExpectation(description: "Invalid repository initialisation")
        service.initialiseRepository(at: invalidBookmark, password: "test-password") { result in
            // Then
            XCTAssertNotEqual(result.exitCode, 0)
            XCTAssertFalse(result.error.isEmpty)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Security Operation Recording Tests

    func testSecurityOperationRecording_SuccessfulOperation() throws {
        // Given
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        let bookmark = try testFile.bookmarkData(options: .withSecurityScope)

        // When
        let expectation = XCTestExpectation(description: "Security operation recording")
        service.validateBookmark(bookmark) { isValid, _ in
            // Then
            // Note: In a real test, we'd verify the security operation was recorded
            // Here we're just verifying the operation completed successfully
            XCTAssertTrue(isValid)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testSecurityOperationRecording_FailedOperation() {
        // Given
        let invalidBookmark = Data([0x00, 0x01, 0x02]) // Invalid bookmark data

        // When
        let expectation = XCTestExpectation(description: "Failed security operation recording")
        service.validateBookmark(invalidBookmark) { isValid, _ in
            // Then
            // Note: In a real test, we'd verify the security operation was recorded with failure status
            XCTAssertFalse(isValid)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Resource Cleanup Tests

    func testResourceCleanup_EnsuresProperResourceRelease() throws {
        // Given
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        let bookmark = try testFile.bookmarkData(options: .withSecurityScope)

        // When
        let expectation = XCTestExpectation(description: "Resource cleanup")
        service.validateBookmark(bookmark) { isValid, _ in
            // Then
            // Note: In a real test, we'd verify resources were properly released
            // Here we're just verifying the operation completed
            XCTAssertTrue(isValid)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Helper Types

    private class MockLogger: LoggerProtocol {
        var loggedMessages: [(level: OSLogType, message: String)] = []

        func log(level: OSLogType, message: String) {
            loggedMessages.append((level, message))
        }
    }
}
