import XCTest
@testable import rBUM
@testable import Core

final class BookmarkPersistenceServiceTests: XCTestCase {
    // MARK: - Properties
    private var service: BookmarkPersistenceService!
    private var mockLogger: MockLogger!
    private var mockKeychainService: MockKeychainService!
    private let fileManager = FileManager.default
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        mockKeychainService = MockKeychainService()
        
        service = BookmarkPersistenceService(
            logger: mockLogger,
            keychainService: mockKeychainService
        )
    }
    
    override func tearDown() {
        service = nil
        mockLogger.clear()
        mockKeychainService.clear()
        super.tearDown()
    }
    
    // MARK: - Persistence Tests
    func testSaveAndLoadBookmark() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-bookmark")
        defer { cleanupTestURLs(testURL) }
        
        let testBookmark = Data.testBookmark(for: testURL)
        mockKeychainService.bookmarkToReturn = testBookmark
        
        // When
        try await service.saveBookmark(testBookmark, for: testURL)
        let loadedBookmark = try await service.loadBookmark(for: testURL)
        
        // Then
        XCTAssertEqual(loadedBookmark, testBookmark)
        verifyLogMessages(mockLogger,
            contains: "Successfully saved bookmark",
                     "Successfully loaded bookmark")
    }
    
    func testDeleteBookmark() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-bookmark")
        defer { cleanupTestURLs(testURL) }
        
        let testBookmark = Data.testBookmark(for: testURL)
        mockKeychainService.bookmarkToReturn = testBookmark
        
        // When
        try await service.saveBookmark(testBookmark, for: testURL)
        try await service.deleteBookmark(for: testURL)
        
        // Then
        await XCTAssertThrowsError(try await service.loadBookmark(for: testURL)) { error in
            XCTAssertTrue(error is BookmarkError)
        }
        verifyLogMessages(mockLogger,
            contains: "Successfully deleted bookmark")
    }
    
    func testLoadNonexistentBookmark() async {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent")
        
        // When/Then
        await XCTAssertThrowsError(try await service.loadBookmark(for: testURL)) { error in
            XCTAssertTrue(error is BookmarkError)
        }
        verifyLogMessages(mockLogger,
            contains: "Failed to load bookmark")
    }
    
    func testSaveInvalidBookmark() async {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        let invalidBookmark = Data()
        
        // When/Then
        await XCTAssertThrowsError(try await service.saveBookmark(invalidBookmark, for: testURL)) { error in
            XCTAssertTrue(error is BookmarkError)
        }
        verifyLogMessages(mockLogger,
            contains: "Failed to save bookmark")
    }
    
    // MARK: - Health Check Tests
    func testHealthCheck() async {
        // Given
        mockKeychainService.isHealthy = true
        
        // When
        let isHealthy = await service.performHealthCheck()
        
        // Then
        XCTAssertTrue(isHealthy)
        verifyLogMessages(mockLogger,
            contains: "Health check completed")
    }
    
    func testHealthCheckFailure() async {
        // Given
        mockKeychainService.isHealthy = false
        
        // When
        let isHealthy = await service.performHealthCheck()
        
        // Then
        XCTAssertFalse(isHealthy)
        verifyLogMessages(mockLogger,
            contains: "Health check failed")
    }
}
