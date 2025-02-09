@testable import Core
import XCTest

final class SecurityScopedAccessTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var testFileURL: URL!
    private var testDirectoryURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary directory for testing
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        
        // Create a test file
        testFileURL = temporaryDirectory.appendingPathComponent("test.txt")
        try "Test content".write(to: testFileURL, atomically: true, encoding: .utf8)
        
        // Create a test directory
        testDirectoryURL = temporaryDirectory.appendingPathComponent("testdir", isDirectory: true)
        try FileManager.default.createDirectory(at: testDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        
        // Clean up temporary directory
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        
        temporaryDirectory = nil
        testFileURL = nil
        testDirectoryURL = nil
    }
    
    func testInitialisationWithFile() throws {
        // Given a valid file URL
        let url = testFileURL
        
        // When creating security-scoped access
        let access = try SecurityScopedAccess(url: url)
        
        // Then it should be initialised correctly
        XCTAssertEqual(access.url, url)
        XCTAssertFalse(access.isAccessing)
    }
    
    func testInitialisationWithDirectory() throws {
        // Given a valid directory URL
        let url = testDirectoryURL
        
        // When creating security-scoped access for directory
        let access = try SecurityScopedAccess(url: url, isDirectory: true)
        
        // Then it should be initialised correctly
        XCTAssertEqual(access.url, url)
        XCTAssertFalse(access.isAccessing)
    }
    
    func testInitialisationWithInvalidURL() throws {
        // Given an invalid URL
        let invalidURL = URL(fileURLWithPath: "/path/that/does/not/exist")
        
        // When creating security-scoped access
        // Then it should throw an error
        XCTAssertThrowsError(try SecurityScopedAccess(url: invalidURL)) { error in
            XCTAssertTrue(error is SecurityScopedAccessError)
        }
    }
    
    func testAccessLifecycle() throws {
        // Given a security-scoped access instance
        let access = try SecurityScopedAccess(url: testFileURL)
        var mutableAccess = access
        
        // When starting access
        try mutableAccess.startAccessing()
        
        // Then access should be granted
        XCTAssertTrue(mutableAccess.isAccessing)
        
        // When stopping access
        mutableAccess.stopAccessing()
        
        // Then access should be revoked
        XCTAssertFalse(mutableAccess.isAccessing)
    }
    
    func testDoubleStartAccess() throws {
        // Given a security-scoped access instance with access started
        let access = try SecurityScopedAccess(url: testFileURL)
        var mutableAccess = access
        try mutableAccess.startAccessing()
        
        // When starting access again
        try mutableAccess.startAccessing()
        
        // Then it should still be accessing
        XCTAssertTrue(mutableAccess.isAccessing)
        
        // Cleanup
        mutableAccess.stopAccessing()
    }
    
    func testDoubleStopAccess() throws {
        // Given a security-scoped access instance
        let access = try SecurityScopedAccess(url: testFileURL)
        var mutableAccess = access
        
        // When stopping access without starting
        mutableAccess.stopAccessing()
        
        // Then it should remain not accessing
        XCTAssertFalse(mutableAccess.isAccessing)
    }
    
    func testCodableConformance() throws {
        // Given a security-scoped access instance
        let access = try SecurityScopedAccess(url: testFileURL)
        
        // When encoding and decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(access)
        let decodedAccess = try decoder.decode(SecurityScopedAccess.self, from: data)
        
        // Then it should maintain equality
        XCTAssertEqual(access, decodedAccess)
    }
    
    func testConcurrentAccess() throws {
        // Given a security-scoped access instance
        let access = try SecurityScopedAccess(url: testFileURL)
        var mutableAccess = access
        
        // When accessing concurrently from multiple threads
        let expectation = XCTestExpectation(description: "Concurrent access complete")
        expectation.expectedFulfillmentCount = 10
        
        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            do {
                try mutableAccess.startAccessing()
                mutableAccess.stopAccessing()
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent access failed: \(error)")
            }
        }
        
        // Then it should complete without errors
        wait(for: [expectation], timeout: 5.0)
    }
}
