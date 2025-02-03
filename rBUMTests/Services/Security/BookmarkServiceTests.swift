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
    
    private var bookmarkService: BookmarkService!
    private var persistenceService: MockBookmarkPersistenceService!
    private var logger: TestLogger!
    private var fileManager: MockFileManager!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        logger = TestLogger()
        persistenceService = MockBookmarkPersistenceService()
        fileManager = MockFileManager()
        
        bookmarkService = BookmarkService(
            persistenceService: persistenceService,
            fileManager: fileManager,
            logger: logger
        )
    }
    
    override func tearDown() async throws {
        bookmarkService = nil
        persistenceService = nil
        logger = nil
        fileManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Bookmark Creation Tests
    
    func testCreateBookmark() throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        fileManager.mockBookmarkData = "test-bookmark-data".data(using: .utf8)!
        
        let bookmarkData = try bookmarkService.createBookmark(for: testURL)
        
        XCTAssertEqual(bookmarkData, fileManager.mockBookmarkData)
        XCTAssertTrue(fileManager.createBookmarkDataCalled)
        XCTAssertTrue(persistenceService.saveBookmarkCalled)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Creating bookmark") })
    }
    
    func testCreateBookmarkWithInvalidURL() throws {
        let invalidURL = URL(fileURLWithPath: "")
        fileManager.shouldFailBookmarkCreation = true
        
        XCTAssertThrowsError(try bookmarkService.createBookmark(for: invalidURL)) { error in
            XCTAssertTrue(error is BookmarkError)
            XCTAssertEqual(error as? BookmarkError, .creationFailed)
        }
        
        // Verify error logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Failed to create bookmark") })
    }
    
    // MARK: - Bookmark Resolution Tests
    
    func testResolveBookmark() throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        let bookmarkData = "test-bookmark-data".data(using: .utf8)!
        fileManager.mockResolvedURL = testURL
        
        let resolvedURL = try bookmarkService.resolveBookmark(bookmarkData)
        
        XCTAssertEqual(resolvedURL, testURL)
        XCTAssertTrue(fileManager.resolveBookmarkDataCalled)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Resolving bookmark") })
    }
    
    func testResolveStaleBookmark() throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        let bookmarkData = "test-bookmark-data".data(using: .utf8)!
        fileManager.mockResolvedURL = testURL
        fileManager.mockBookmarkIsStale = true
        
        // First resolution should recreate the bookmark
        let resolvedURL = try bookmarkService.resolveBookmark(bookmarkData)
        
        XCTAssertEqual(resolvedURL, testURL)
        XCTAssertTrue(fileManager.resolveBookmarkDataCalled)
        XCTAssertTrue(fileManager.createBookmarkDataCalled)
        XCTAssertTrue(persistenceService.saveBookmarkCalled)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Bookmark is stale") })
        XCTAssertTrue(logger.messages.contains { $0.contains("Recreated stale bookmark") })
    }
    
    // MARK: - Access Control Tests
    
    func testAccessControl() throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        fileManager.mockResolvedURL = testURL
        
        XCTAssertTrue(bookmarkService.startAccessing(testURL))
        XCTAssertTrue(fileManager.startAccessingSecurityScopedResourceCalled)
        
        bookmarkService.stopAccessing(testURL)
        XCTAssertTrue(fileManager.stopAccessingSecurityScopedResourceCalled)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Started accessing") })
        XCTAssertTrue(logger.messages.contains { $0.contains("Stopped accessing") })
    }
    
    func testNestedAccess() throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        fileManager.mockResolvedURL = testURL
        
        // First access
        XCTAssertTrue(bookmarkService.startAccessing(testURL))
        XCTAssertEqual(fileManager.startAccessingCount, 1)
        
        // Nested access
        XCTAssertTrue(bookmarkService.startAccessing(testURL))
        XCTAssertEqual(fileManager.startAccessingCount, 1) // Should not increment
        
        // First stop
        bookmarkService.stopAccessing(testURL)
        XCTAssertEqual(fileManager.stopAccessingCount, 0) // Should not stop yet
        
        // Second stop
        bookmarkService.stopAccessing(testURL)
        XCTAssertEqual(fileManager.stopAccessingCount, 1) // Should stop now
    }
    
    // MARK: - Persistence Tests
    
    func testBookmarkPersistence() throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        let bookmarkData = "test-bookmark-data".data(using: .utf8)!
        fileManager.mockBookmarkData = bookmarkData
        
        // Create and save bookmark
        let savedData = try bookmarkService.createBookmark(for: testURL)
        XCTAssertTrue(persistenceService.saveBookmarkCalled)
        XCTAssertEqual(persistenceService.lastSavedBookmark, savedData)
        
        // Retrieve bookmark
        persistenceService.mockBookmarkData = bookmarkData
        let retrievedData = try persistenceService.retrieveBookmark(for: testURL)
        XCTAssertEqual(retrievedData, bookmarkData)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Saved bookmark") })
        XCTAssertTrue(logger.messages.contains { $0.contains("Retrieved bookmark") })
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentAccess() async throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        fileManager.mockResolvedURL = testURL
        let iterations = 100
        
        await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    XCTAssertTrue(self.bookmarkService.startAccessing(testURL))
                    try await Task.sleep(nanoseconds: 1_000_000)
                    self.bookmarkService.stopAccessing(testURL)
                }
            }
        }
        
        XCTAssertEqual(fileManager.startAccessingCount, 1)
        XCTAssertEqual(fileManager.stopAccessingCount, 1)
    }
}

// MARK: - Test Helpers

private final class MockFileManager: FileManagerProtocol {
    var createBookmarkDataCalled = false
    var resolveBookmarkDataCalled = false
    var startAccessingSecurityScopedResourceCalled = false
    var stopAccessingSecurityScopedResourceCalled = false
    
    var startAccessingCount = 0
    var stopAccessingCount = 0
    
    var shouldFailBookmarkCreation = false
    var mockBookmarkIsStale = false
    var mockBookmarkData: Data?
    var mockResolvedURL: URL?
    
    func createBookmarkData(for url: URL) throws -> Data {
        createBookmarkDataCalled = true
        
        if shouldFailBookmarkCreation {
            throw BookmarkError.creationFailed
        }
        
        return mockBookmarkData ?? Data()
    }
    
    func resolveBookmarkData(_ data: Data) throws -> (URL, Bool) {
        resolveBookmarkDataCalled = true
        return (mockResolvedURL ?? URL(fileURLWithPath: "/test"), mockBookmarkIsStale)
    }
    
    func startAccessingSecurityScopedResource(_ url: URL) -> Bool {
        startAccessingSecurityScopedResourceCalled = true
        startAccessingCount += 1
        return true
    }
    
    func stopAccessingSecurityScopedResource(_ url: URL) {
        stopAccessingSecurityScopedResourceCalled = true
        stopAccessingCount += 1
    }
}

private final class MockBookmarkPersistenceService: BookmarkPersistenceServiceProtocol {
    var saveBookmarkCalled = false
    var retrieveBookmarkCalled = false
    
    var lastSavedBookmark: Data?
    var mockBookmarkData: Data?
    
    func saveBookmark(_ data: Data, for url: URL) throws {
        saveBookmarkCalled = true
        lastSavedBookmark = data
    }
    
    func retrieveBookmark(for url: URL) throws -> Data {
        retrieveBookmarkCalled = true
        return mockBookmarkData ?? Data()
    }
}
