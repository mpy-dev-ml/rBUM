import XCTest
@testable import Core

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
            "key3": .bool(true),
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

private struct LogContext {
    let level: LogLevel
    let message: String
    let metadata: [String: LogMetadataValue]?
    let privacy: LogPrivacy
    let error: Error?
    let file: String
    let function: String
    let line: Int
}

private struct LogParameters {
    let level: LogLevel
    let message: String
    let metadata: [String: LogMetadataValue]?
    let privacy: LogPrivacy
    let error: Error?
    let file: String
    let function: String
    let line: Int

    init(
        level: LogLevel,
        message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .private,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.level = level
        self.message = message
        self.metadata = metadata
        self.privacy = privacy
        self.error = error
        self.file = file
        self.function = function
        self.line = line
    }
}

private final class TestLogOutput {
    var lastContext: LogContext?

    var lastLevel: LogLevel? { lastContext?.level }
    var lastMessage: String? { lastContext?.message }
    var lastMetadata: [String: LogMetadataValue]? { lastContext?.metadata }
    var lastPrivacy: LogPrivacy? { lastContext?.privacy }
    var lastError: Error? { lastContext?.error }
    var lastFile: String? { lastContext?.file }
    var lastFunction: String? { lastContext?.function }
    var lastLine: Int? { lastContext?.line }

    func log(_ context: LogContext) {
        lastContext = context
    }
}

private final class TestLogger: LoggerProtocol {
    let output: TestLogOutput

    init(output: TestLogOutput) {
        self.output = output
    }

    func log(parameters: LogParameters) {
        let context = LogContext(
            level: parameters.level,
            message: parameters.message,
            metadata: parameters.metadata,
            privacy: parameters.privacy,
            error: parameters.error,
            file: parameters.file,
            function: parameters.function,
            line: parameters.line
        )
        output.log(context)
    }

    // Convenience method that maintains the original interface
    func log(
        level: LogLevel,
        message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .private,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let params = LogParameters(
            level: level,
            message: message,
            metadata: metadata,
            privacy: privacy,
            error: error,
            file: file,
            function: function,
            line: line
        )
        log(parameters: params)
    }
}
