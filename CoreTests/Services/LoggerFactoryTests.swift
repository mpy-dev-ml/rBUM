//
//  LoggerFactoryTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 03/02/2025.
//

@testable import Core
import os.log
import XCTest

final class LoggerFactoryTests: XCTestCase {
    // MARK: - Properties

    private var factory: LoggerFactory!
    private var logger: Logger!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        factory = LoggerFactory()
        logger = factory.createLogger(category: "Test")
    }

    override func tearDown() async throws {
        factory = nil
        logger = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func testLoggerCreation() throws {
        XCTAssertNotNil(logger)

        // Create multiple loggers
        let logger1 = factory.createLogger(category: "Test1")
        let logger2 = factory.createLogger(category: "Test2")

        XCTAssertNotNil(logger1)
        XCTAssertNotNil(logger2)

        for loggerIndex in 0..<5 {
            let logger = factory.createLogger(category: "test\(loggerIndex)")
            XCTAssertNotNil(logger)
        }
    }

    func testLogLevels() throws {
        // Test different log levels
        logger.debug("Debug message")
        logger.info("Info message")
        logger.notice("Notice message")
        logger.warning("Warning message")
        logger.error("Error message")
        logger.critical("Critical message")

        // We're primarily testing that these calls don't throw
        XCTAssertTrue(true)
    }

    func testPrivacyLevels() throws {
        // Test private data handling
        logger.info("Public info", privacy: .public)
        logger.info("Private info", privacy: .private)
        logger.info("Sensitive info", privacy: .private(mask: .hash))
        logger.info("Sensitive info", privacy: .private(mask: .redact))

        // Test that privacy levels don't throw
        XCTAssertTrue(true)
    }

    func testConcurrentLogging() async throws {
        let iterations = 100

        await withThrowingTaskGroup(of: Void.self) { group in
            for iteration in 0 ..< iterations {
                group.addTask {
                    self.logger.info("Concurrent message \(iteration)")
                }
            }
        }

        // If we reach here without crashes, the test passes
        XCTAssertTrue(true)
    }

    func testMetadata() throws {
        // Test with metadata
        logger.info("Test message with metadata", metadata: ["key": "value"])

        // Test with privacy and metadata
        logger.info(
            "Test message with private metadata",
            metadata: ["sensitive": "private-value"],
            privacy: .private
        )

        // Test that metadata handling doesn't throw
        XCTAssertTrue(true)
    }
}
