import XCTest
@testable import Core
@testable import rBUM

/// Test suite for DefaultSecurityService validation functionality
final class DefaultSecurityServiceValidationTests: XCTestCase {
    // MARK: - Properties

    var service: DefaultSecurityService!
    var mockLogger: MockLogger!
    var mockBookmarkService: MockBookmarkService!
    var mockKeychainService: MockKeychainService!
    let fileManager = FileManager.default

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
        mockLogger = nil
        mockBookmarkService = nil
        mockKeychainService = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testInvalidCredentials() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-invalid-creds")
        defer { cleanupTestURLs(testURL) }

        // When
        let result = await service.validateCredentials(for: testURL)

        // Then
        XCTAssertFalse(result)
        XCTAssertTrue(mockLogger.messages.contains { $msg in
            $msg.contains("Invalid credentials") && $msg.contains(testURL.path)
        })
    }
}
