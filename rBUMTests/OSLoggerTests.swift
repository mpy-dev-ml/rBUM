//
//  OSLoggerTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
@testable import Core
import os.log
@testable import rBUM
import XCTest

final class OSLoggerTests: XCTestCase {
    // MARK: - Properties
    private var logger: OSLogger!
    private let subsystem = "dev.mpy.rBUM"
    private let category = "Tests"
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        logger = OSLogger(subsystem: subsystem, category: category)
    }
    
    override func tearDown() {
        logger = nil
        super.tearDown()
    }
    
    // MARK: - Logging Tests
    func testDebugLogging() {
        // Given
        let message = "Debug test message"
        
        // When
        logger.debug(message)
        
        // Then
        // Note: We can't directly verify OS_LOG output in tests,
        // but we can verify the logger doesn't crash and handles the call
        XCTAssertNotNil(logger)
    }
    
    func testInfoLogging() {
        // Given
        let message = "Info test message"
        
        // When
        logger.info(message)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    func testWarningLogging() {
        // Given
        let message = "Warning test message"
        
        // When
        logger.warning(message)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    func testErrorLogging() {
        // Given
        let message = "Error test message"
        
        // When
        logger.error(message)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    func testCriticalLogging() {
        // Given
        let message = "Critical test message"
        
        // When
        logger.critical(message)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    // MARK: - Privacy Level Tests
    func testPublicPrivacyLevel() {
        // Given
        let message = "Public test message"
        
        // When
        logger.debug(message, privacy: .public)
        logger.info(message, privacy: .public)
        logger.warning(message, privacy: .public)
        logger.error(message, privacy: .public)
        logger.critical(message, privacy: .public)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    func testPrivatePrivacyLevel() {
        // Given
        let message = "Private test message"
        
        // When
        logger.debug(message, privacy: .private)
        logger.info(message, privacy: .private)
        logger.warning(message, privacy: .private)
        logger.error(message, privacy: .private)
        logger.critical(message, privacy: .private)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    func testSensitivePrivacyLevel() {
        // Given
        let message = "Sensitive test message"
        
        // When
        logger.debug(message, privacy: .sensitive)
        logger.info(message, privacy: .sensitive)
        logger.warning(message, privacy: .sensitive)
        logger.error(message, privacy: .sensitive)
        logger.critical(message, privacy: .sensitive)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    // MARK: - Error Logging Tests
    func testErrorObjectLogging() {
        // Given
        struct TestError: Error {
            let message: String
        }
        let error = TestError(message: "Test error")
        
        // When
        logger.error("An error occurred", error: error)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    func testNSErrorLogging() {
        // Given
        let error = NSError(domain: "TestDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test NSError"])
        
        // When
        logger.error("An NSError occurred", error: error)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    // MARK: - Metadata Tests
    func testLoggingWithMetadata() {
        // Given
        let message = "Test message with metadata"
        let metadata = ["key1": "value1", "key2": "value2"]
        
        // When
        logger.debug(message, metadata: metadata)
        logger.info(message, metadata: metadata)
        logger.warning(message, metadata: metadata)
        logger.error(message, metadata: metadata)
        logger.critical(message, metadata: metadata)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    func testLoggingWithEmptyMetadata() {
        // Given
        let message = "Test message with empty metadata"
        let metadata: [String: String] = [:]
        
        // When
        logger.debug(message, metadata: metadata)
        logger.info(message, metadata: metadata)
        logger.warning(message, metadata: metadata)
        logger.error(message, metadata: metadata)
        logger.critical(message, metadata: metadata)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    // MARK: - Health Check Tests
    func testHealthCheck() async {
        // When
        let isHealthy = await logger.performHealthCheck()
        
        // Then
        XCTAssertTrue(isHealthy)
    }
    
    // MARK: - Edge Cases
    func testEmptyMessageLogging() {
        // Given
        let message = ""
        
        // When
        logger.debug(message)
        logger.info(message)
        logger.warning(message)
        logger.error(message)
        logger.critical(message)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    func testVeryLongMessageLogging() {
        // Given
        let message = String(repeating: "A", count: 1024)
        
        // When
        logger.debug(message)
        logger.info(message)
        logger.warning(message)
        logger.error(message)
        logger.critical(message)
        
        // Then
        XCTAssertNotNil(logger)
    }
    
    func testUnicodeMessageLogging() {
        // Given
        let message = "Unicode test: 🧪📝🔍✅"
        
        // When
        logger.debug(message)
        logger.info(message)
        logger.warning(message)
        logger.error(message)
        logger.critical(message)
        
        // Then
        XCTAssertNotNil(logger)
    }
}
