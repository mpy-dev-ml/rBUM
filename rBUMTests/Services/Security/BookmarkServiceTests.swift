//
//  BookmarkServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 03/02/2025.
//

import XCTest
@testable import rBUM
@testable import Core

final class BookmarkServiceTests: XCTestCase {
    // MARK: - Properties
    private var service: BookmarkService!
    private var mockLogger: MockLogger!
    private var mockKeychainService: MockKeychainService!
    private let fileManager = FileManager.default
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        mockKeychainService = MockKeychainService()
        
        service = BookmarkService(
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
    
    // MARK: - Bookmark Management Tests
    func testCreateAndValidateBookmark() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-bookmark")
        defer { cleanupTestURLs(testURL) }
        
        // When
        let bookmark = try await service.createBookmark(for: testURL)
        let isValid = try await service.validateBookmark(bookmark, for: testURL)
        
        // Then
        XCTAssertTrue(isValid)
        verifyLogMessages(mockLogger,
            contains: "Successfully created bookmark",
                     "Successfully validated bookmark")
    }
    
    func testStartAndStopAccessing() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-access")
        defer { cleanupTestURLs(testURL) }
        
        let bookmark = try await service.createBookmark(for: testURL)
        
        // When
        let startResult = try await service.startAccessing(testURL, with: bookmark)
        let stopResult = try await service.stopAccessing(testURL)
        
        // Then
        XCTAssertTrue(startResult)
        XCTAssertTrue(stopResult)
        verifyLogMessages(mockLogger,
            contains: "Successfully started accessing URL",
                     "Successfully stopped accessing URL")
    }
    
    func testBookmarkStaleness() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-stale")
        defer { cleanupTestURLs(testURL) }
        
        let bookmark = try await service.createBookmark(for: testURL)
        try fileManager.moveItem(at: testURL, to: testURL.appendingPathComponent("moved"))
        
        // When/Then
        await XCTAssertThrowsError(try await service.validateBookmark(bookmark, for: testURL)) { error in
            XCTAssertTrue(error is BookmarkError)
        }
        verifyLogMessages(mockLogger,
            contains: "Bookmark validation failed")
    }
    
    func testAccessWithInvalidBookmark() async throws {
        // Given
        let testURL = try URL.temporaryTestDirectory(name: "test-invalid")
        defer { cleanupTestURLs(testURL) }
        
        let invalidBookmark = Data()
        
        // When/Then
        await XCTAssertThrowsError(try await service.startAccessing(testURL, with: invalidBookmark)) { error in
            XCTAssertTrue(error is BookmarkError)
        }
        verifyLogMessages(mockLogger,
            contains: "Failed to start accessing URL")
    }
    
    func testConcurrentAccess() async throws {
        // Given
        let testURL1 = try URL.temporaryTestDirectory(name: "test-concurrent-1")
        let testURL2 = try URL.temporaryTestDirectory(name: "test-concurrent-2")
        defer {
            cleanupTestURLs(testURL1, testURL2)
        }
        
        let bookmark1 = try await service.createBookmark(for: testURL1)
        let bookmark2 = try await service.createBookmark(for: testURL2)
        
        // When
        async let access1 = service.startAccessing(testURL1, with: bookmark1)
        async let access2 = service.startAccessing(testURL2, with: bookmark2)
        
        // Then
        let (result1, result2) = try await (access1, access2)
        XCTAssertTrue(result1)
        XCTAssertTrue(result2)
        
        // Cleanup
        try await service.stopAccessing(testURL1)
        try await service.stopAccessing(testURL2)
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
            contains: "Health check completed successfully")
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
