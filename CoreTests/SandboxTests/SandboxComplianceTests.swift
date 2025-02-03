import Foundation
import XCTest
@testable import Core
@testable import rBUM

class SandboxComplianceTests: XCTestCase {
    var securityService: SecurityService!
    var logger: MockLogger!
    var fileManager: FileManager!
    var testDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        logger = MockLogger()
        fileManager = FileManager.default
        securityService = SecurityService(logger: logger)
        
        // Create test directory in sandbox-safe location
        testDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("dev.mpy.rBUM.tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try fileManager.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        try? fileManager.removeItem(at: testDirectory)
        securityService = nil
        logger = nil
        fileManager = nil
        testDirectory = nil
    }
    
    // MARK: - Security-Scoped Resource Tests
    
    func testSecurityScopedResourceAccess() async throws {
        // Create a test file
        let testFile = testDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Test starting access
        XCTAssertTrue(securityService.startAccessing(testFile))
        
        // Verify we can read the file
        XCTAssertTrue(fileManager.fileExists(atPath: testFile.path))
        let content = try String(contentsOf: testFile, encoding: .utf8)
        XCTAssertEqual(content, "test content")
        
        // Test stopping access
        securityService.stopAccessing(testFile)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { message in
            message.level == .debug && message.text.contains("Started accessing resource")
        })
        XCTAssertTrue(logger.messages.contains { message in
            message.level == .debug && message.text.contains("Stopped accessing resource")
        })
    }
    
    func testMultipleResourceAccess() async throws {
        // Create test files
        let file1 = testDirectory.appendingPathComponent("file1.txt")
        let file2 = testDirectory.appendingPathComponent("file2.txt")
        
        try "content 1".write(to: file1, atomically: true, encoding: .utf8)
        try "content 2".write(to: file2, atomically: true, encoding: .utf8)
        
        // Start accessing both files
        XCTAssertTrue(securityService.startAccessing(file1))
        XCTAssertTrue(securityService.startAccessing(file2))
        
        // Verify we can read both files
        XCTAssertEqual(try String(contentsOf: file1, encoding: .utf8), "content 1")
        XCTAssertEqual(try String(contentsOf: file2, encoding: .utf8), "content 2")
        
        // Stop accessing in reverse order
        securityService.stopAccessing(file2)
        securityService.stopAccessing(file1)
        
        // Verify proper logging
        XCTAssertEqual(
            logger.messages.filter { $0.text.contains("Started accessing resource") }.count,
            2
        )
        XCTAssertEqual(
            logger.messages.filter { $0.text.contains("Stopped accessing resource") }.count,
            2
        )
    }
    
    func testResourceAccessCleanup() async throws {
        let testFile = testDirectory.appendingPathComponent("cleanup_test.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Create a new scope to test cleanup
        do {
            let tempService = SecurityService(logger: logger)
            XCTAssertTrue(tempService.startAccessing(testFile))
            // Service will be deallocated here
        }
        
        // Verify cleanup warning was logged
        XCTAssertTrue(logger.messages.contains { message in
            message.level == .warning && message.text.contains("Resource access not properly stopped")
        })
    }
    
    // MARK: - Bookmark Tests
    
    func testBookmarkCreationAndResolution() async throws {
        let testFile = testDirectory.appendingPathComponent("bookmark_test.txt")
        try "bookmark test".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Create bookmark
        let bookmark = try await securityService.createBookmark(for: testFile)
        XCTAssertFalse(bookmark.isEmpty)
        
        // Resolve bookmark
        let resolvedURL = try await securityService.resolveBookmark(bookmark)
        XCTAssertEqual(resolvedURL.path, testFile.path)
        
        // Verify we can access the resolved URL
        XCTAssertTrue(securityService.startAccessing(resolvedURL))
        XCTAssertEqual(try String(contentsOf: resolvedURL, encoding: .utf8), "bookmark test")
        securityService.stopAccessing(resolvedURL)
    }
    
    func testInvalidBookmarkHandling() async throws {
        // Test with invalid bookmark data
        let invalidBookmark = Data([0x00, 0x01, 0x02, 0x03])
        
        do {
            _ = try await securityService.resolveBookmark(invalidBookmark)
            XCTFail("Expected error for invalid bookmark")
        } catch {
            XCTAssertTrue(error is SecurityError)
        }
        
        // Verify error was logged
        XCTAssertTrue(logger.messages.contains { message in
            message.level == .error && message.text.contains("Failed to resolve bookmark")
        })
    }
}
