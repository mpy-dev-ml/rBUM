//
//  SandboxMonitorTests.swift
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

final class SandboxMonitorTests: XCTestCase {
    // MARK: - Properties
    private var monitor: SandboxMonitor!
    private var mockLogger: MockLogger!
    private let fileManager = FileManager.default
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        mockLogger = MockLogger()
        monitor = SandboxMonitor(logger: mockLogger)
    }
    
    override func tearDown() {
        monitor = nil
        mockLogger.clear()
        super.tearDown()
    }
    
    // MARK: - Tests
    func testTrackResourceAccess() throws {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        try "test".write(to: testURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testURL) }
        
        // When
        monitor.trackResourceAccess(to: testURL)
        
        // Then
        XCTAssertTrue(monitor.checkResourceAccess(to: testURL))
        XCTAssertTrue(mockLogger.containsMessage("Started tracking resource access"))
    }
    
    func testStopTrackingResource() throws {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        try "test".write(to: testURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testURL) }
        
        monitor.trackResourceAccess(to: testURL)
        XCTAssertTrue(monitor.checkResourceAccess(to: testURL))
        
        // When
        monitor.stopTrackingResource(testURL)
        
        // Then
        XCTAssertFalse(monitor.checkResourceAccess(to: testURL))
        XCTAssertTrue(mockLogger.containsMessage("Stopped tracking resource"))
    }
    
    func testCheckResourceAccessWithNonexistentResource() {
        // Given
        let nonexistentURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent")
        
        // When/Then
        XCTAssertFalse(monitor.checkResourceAccess(to: nonexistentURL))
        XCTAssertTrue(mockLogger.containsMessage("Resource not found"))
    }
    
    func testTrackMultipleResources() throws {
        // Given
        let testURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("test1")
        let testURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("test2")
        try "test1".write(to: testURL1, atomically: true, encoding: .utf8)
        try "test2".write(to: testURL2, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: testURL1)
            try? FileManager.default.removeItem(at: testURL2)
        }
        
        // When
        monitor.trackResourceAccess(to: testURL1)
        monitor.trackResourceAccess(to: testURL2)
        
        // Then
        XCTAssertTrue(monitor.checkResourceAccess(to: testURL1))
        XCTAssertTrue(monitor.checkResourceAccess(to: testURL2))
    }
    
    func testStopTrackingMultipleResources() throws {
        // Given
        let testURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("test1")
        let testURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("test2")
        try "test1".write(to: testURL1, atomically: true, encoding: .utf8)
        try "test2".write(to: testURL2, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: testURL1)
            try? FileManager.default.removeItem(at: testURL2)
        }
        
        monitor.trackResourceAccess(to: testURL1)
        monitor.trackResourceAccess(to: testURL2)
        
        // When
        monitor.stopTrackingResource(testURL1)
        
        // Then
        XCTAssertFalse(monitor.checkResourceAccess(to: testURL1))
        XCTAssertTrue(monitor.checkResourceAccess(to: testURL2))
    }
    
    func testTrackInvalidURL() {
        // Given
        let invalidURL = URL(string: "")!
        
        // When
        monitor.trackResourceAccess(to: invalidURL)
        
        // Then
        XCTAssertFalse(monitor.checkResourceAccess(to: invalidURL))
        XCTAssertTrue(mockLogger.containsMessage("Invalid URL provided"))
    }
    
    func testHealthCheck() async {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        try? "test".write(to: testURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testURL) }
        
        monitor.trackResourceAccess(to: testURL)
        
        // When
        let isHealthy = await monitor.performHealthCheck()
        
        // Then
        XCTAssertTrue(isHealthy)
        XCTAssertTrue(mockLogger.containsMessage("Sandbox monitor health check passed"))
    }
    
    func testHealthCheckWithNoResources() async {
        // When
        let isHealthy = await monitor.performHealthCheck()
        
        // Then
        XCTAssertTrue(isHealthy)
        XCTAssertTrue(mockLogger.containsMessage("Sandbox monitor health check passed"))
    }
    
    func testTrackResourceWithoutPermissions() throws {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        try "test".write(to: testURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: testURL.path)
        defer { try? FileManager.default.removeItem(at: testURL) }
        
        // When
        monitor.trackResourceAccess(to: testURL)
        
        // Then
        XCTAssertFalse(monitor.checkResourceAccess(to: testURL))
        XCTAssertTrue(mockLogger.containsMessage("Failed to track resource access"))
    }
    
    func testResourceAccessAfterDeletion() throws {
        // Given
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test")
        try "test".write(to: testURL, atomically: true, encoding: .utf8)
        monitor.trackResourceAccess(to: testURL)
        
        // When
        try FileManager.default.removeItem(at: testURL)
        
        // Then
        XCTAssertFalse(monitor.checkResourceAccess(to: testURL))
        XCTAssertTrue(mockLogger.containsMessage("Resource not found"))
    }
}
