//
//  LoggerTests.swift
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
import XCTest

final class LoggerTests: XCTestCase {
    // MARK: - Properties
    
    private var logger: LoggerProtocol!
    private var testOutput: TestLogOutput!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        testOutput = TestLogOutput()
        logger = TestLogger(output: testOutput)
    }
    
    override func tearDown() async throws {
        logger = nil
        testOutput = nil
        try await super.tearDown()
    }
    
    // MARK: - Tests
    
    func testDebugLogging() throws {
        let message = "Test debug message"
        logger.debug(message, privacy: .public)
        
        XCTAssertEqual(testOutput.lastLevel, .debug)
        XCTAssertEqual(testOutput.lastMessage, message)
        XCTAssertEqual(testOutput.lastPrivacy, .public)
    }
    
    func testInfoLogging() throws {
        let message = "Test info message"
        logger.info(message, privacy: .private)
        
        XCTAssertEqual(testOutput.lastLevel, .info)
        XCTAssertEqual(testOutput.lastMessage, message)
        XCTAssertEqual(testOutput.lastPrivacy, .private)
    }
    
    func testWarningLogging() throws {
        let message = "Test warning message"
        logger.warning(message, privacy: .sensitive)
        
        XCTAssertEqual(testOutput.lastLevel, .warning)
        XCTAssertEqual(testOutput.lastMessage, message)
        XCTAssertEqual(testOutput.lastPrivacy, .sensitive)
    }
    
    func testErrorLogging() throws {
        let message = "Test error message"
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        logger.error(message, error: error, privacy: .private)
        
        XCTAssertEqual(testOutput.lastLevel, .error)
        XCTAssertEqual(testOutput.lastMessage, message)
        XCTAssertEqual(testOutput.lastError as NSError?, error)
        XCTAssertEqual(testOutput.lastPrivacy, .private)
    }
    
    func testMetadataLogging() throws {
        let message = "Test metadata message"
        let metadata: [String: LogMetadataValue] = [
            "key1": .string("value1"),
            "key2": .int(42),
            "key3": .bool(true)
        ]
        
        logger.debug(
            message,
            metadata: metadata,
            privacy: .public
        )
        
        XCTAssertEqual(testOutput.lastLevel, .debug)
        XCTAssertEqual(testOutput.lastMessage, message)
        XCTAssertEqual(testOutput.lastMetadata?["key1"], .string("value1"))
        XCTAssertEqual(testOutput.lastMetadata?["key2"], .int(42))
        XCTAssertEqual(testOutput.lastMetadata?["key3"], .bool(true))
    }
    
    func testSourceLocationLogging() throws {
        let message = "Test location message"
        let file = "TestFile.swift"
        let function = "testFunction()"
        let line = 42
        
        logger.debug(
            message,
            privacy: .public,
            file: file,
            function: function,
            line: line
        )
        
        XCTAssertEqual(testOutput.lastFile, file)
        XCTAssertEqual(testOutput.lastFunction, function)
        XCTAssertEqual(testOutput.lastLine, line)
    }
}

// MARK: - Test Helpers

private final class TestLogOutput {
    var lastLevel: LogLevel?
    var lastMessage: String?
    var lastMetadata: [String: LogMetadataValue]?
    var lastPrivacy: LogPrivacy?
    var lastError: Error?
    var lastFile: String?
    var lastFunction: String?
    var lastLine: Int?
}

private final class TestLogger: LoggerProtocol {
    private let output: TestLogOutput
    
    init(output: TestLogOutput) {
        self.output = output
    }
    
    func log(
        level: LogLevel,
        message: String,
        metadata: [String: LogMetadataValue]?,
        privacy: LogPrivacy,
        error: Error?,
        file: String,
        function: String,
        line: Int
    ) {
        output.lastLevel = level
        output.lastMessage = message
        output.lastMetadata = metadata
        output.lastPrivacy = privacy
        output.lastError = error
        output.lastFile = file
        output.lastFunction = function
        output.lastLine = line
    }
}
