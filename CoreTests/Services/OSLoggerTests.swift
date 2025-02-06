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
import Testing
@testable import Core
import os.log

struct OSLoggerTests {
    let subsystem = "dev.mpy.rBUM.tests"
    let category = "OSLoggerTests"
    
    @Test
    func testLoggerInitialisation() async throws {
        let logger = OSLogger(subsystem: subsystem, category: category)
        #expect(logger.subsystem == subsystem)
        #expect(logger.category == category)
    }
    
    @Test
    func testDebugLogging() async throws {
        let logger = OSLogger(subsystem: subsystem, category: category)
        // Debug logging should not throw
        #expect { try logger.debug("Test debug message") }
    }
    
    @Test
    func testInfoLogging() async throws {
        let logger = OSLogger(subsystem: subsystem, category: category)
        // Info logging should not throw
        #expect { try logger.info("Test info message") }
    }
    
    @Test
    func testErrorLogging() async throws {
        let logger = OSLogger(subsystem: subsystem, category: category)
        // Error logging should not throw
        #expect { try logger.error("Test error message") }
    }
    
    @Test
    func testPrivacyLevels() async throws {
        let logger = OSLogger(subsystem: subsystem, category: category)
        let privatePath = "/private/path/to/file"
        
        // Test private data logging
        #expect {
            try logger.debug("Processing file: \(privatePath, privacy: .private)")
            try logger.info("Accessing: \(privatePath, privacy: .private)")
            try logger.error("Failed to access: \(privatePath, privacy: .private)")
        }
    }
    
    @Test
    func testSourceLocationLogging() async throws {
        let logger = OSLogger(subsystem: subsystem, category: category)
        let file = "TestFile.swift"
        let function = "testFunction()"
        let line = 42
        
        // Test logging with source location
        #expect {
            try logger.debug("Test message", file: file, function: function, line: line)
            try logger.info("Test message", file: file, function: function, line: line)
            try logger.error("Test message", file: file, function: function, line: line)
        }
    }
}
