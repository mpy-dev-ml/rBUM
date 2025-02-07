//
//  XPCSecurityTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
@testable import Core
@testable import rBUM
import XCTest

final class XPCSecurityTests: XCTestCase {
    private var securityService: SecurityService!
    private var mockXPC: MockXPCService!
    private var mockLogger: MockLogger!
    private var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        mockXPC = MockXPCService()
        mockLogger = MockLogger()
        securityService = SecurityService(logger: mockLogger, xpcService: mockXPC)

        // Create temporary test file
        let tempDir = FileManager.default.temporaryDirectory
        tempURL = tempDir.appendingPathComponent("test_file.txt")
        try "test content".write(to: tempURL, atomically: true, encoding: .utf8)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempURL)
        tempURL = nil
        securityService = nil
        mockXPC = nil
        mockLogger = nil
        try await super.tearDown()
    }

    // MARK: - XPC Connection Tests

    func testXPCConnectionSuccess() async throws {
        // Test successful connection
        try await securityService.validateXPCService()
        XCTAssertTrue(mockXPC.isConnected)
    }

    func testXPCConnectionFailure() async throws {
        // Test connection failure
        mockXPC.shouldFailConnection = true
        await XCTAssertThrowsError(try securityService.validateXPCService()) { error in
            XCTAssertTrue(error is SecurityError)
            if case .xpcConnectionFailed = error as? SecurityError {
                // Expected error
            } else {
                XCTFail("Unexpected error type")
            }
        }
    }

    // MARK: - Bookmark Sharing Tests

    func testBookmarkSharingWithXPC() async throws {
        // Create and share bookmark
        let bookmark = try await securityService.createBookmark(for: tempURL)
        let xpcData = try await securityService.prepareForXPCAccess(tempURL)

        // Execute command using bookmark
        try await mockXPC.executeCommand("test", withBookmark: xpcData)

        // Verify bookmark was used
        XCTAssertNotNil(mockXPC.lastBookmark)
        XCTAssertEqual(mockXPC.accessStartCount, 1)
    }

    func testBookmarkCleanup() async throws {
        // Start accessing
        let bookmark = try await securityService.createBookmark(for: tempURL)
        XCTAssertTrue(securityService.startAccessing(tempURL))
        XCTAssertEqual(mockXPC.accessStartCount, 1)

        // Stop accessing
        securityService.stopAccessing(tempURL)
        XCTAssertEqual(mockXPC.accessStopCount, 1)
        XCTAssertTrue(mockXPC.accessedURLs.isEmpty)
    }

    // MARK: - Permission Tests

    func testXPCPermissionValidation() async throws {
        // Test permission validation
        let isValid = try await securityService.validateXPCService()
        XCTAssertTrue(isValid)

        // Test with disconnected service
        mockXPC.isConnected = false
        await XCTAssertThrowsError(try securityService.validateXPCService())
    }

    func testPermissionDenial() async throws {
        // Test permission denial
        mockXPC.shouldFailExecution = true
        await XCTAssertThrowsError(try mockXPC.executeCommand("test", withBookmark: Data())) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }

    // MARK: - Resource Management Tests

    func testResourceAccessLifecycle() async throws {
        // Test complete resource access lifecycle
        let bookmark = try await securityService.createBookmark(for: tempURL)
        let xpcData = try await securityService.prepareForXPCAccess(tempURL)

        // Start access
        XCTAssertTrue(securityService.startAccessing(tempURL))
        XCTAssertEqual(mockXPC.accessStartCount, 1)

        // Execute command
        _ = try await mockXPC.executeCommand("test", withBookmark: xpcData)

        // Stop access
        securityService.stopAccessing(tempURL)
        XCTAssertEqual(mockXPC.accessStopCount, 1)
        XCTAssertTrue(mockXPC.accessedURLs.isEmpty)
    }

    func testConcurrentAccess() async throws {
        // Test concurrent access from multiple operations
        let bookmark = try await securityService.createBookmark(for: tempURL)
        let xpcData = try await securityService.prepareForXPCAccess(tempURL)

        // Simulate concurrent access
        async let op1 = mockXPC.executeCommand("test1", withBookmark: xpcData)
        async let op2 = mockXPC.executeCommand("test2", withBookmark: xpcData)

        _ = try await [op1, op2]

        // Verify command history
        XCTAssertEqual(mockXPC.commandHistory.count, 2)
        XCTAssertEqual(mockXPC.accessStartCount, 2)
        XCTAssertEqual(mockXPC.accessStopCount, 2)
    }
}
