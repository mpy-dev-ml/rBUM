//
//  LoggerProtocol.swift
//  Core
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation
import os.log

/// Protocol for logging messages with different privacy levels
public protocol LoggerProtocol {
    /// Log a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    func debug(_ message: String, file: String, function: String, line: Int)
    
    /// Log an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    func info(_ message: String, file: String, function: String, line: Int)
    
    /// Log an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    func error(_ message: String, file: String, function: String, line: Int)
}

#if os(macOS)
/// macOS-specific logger implementation using os.Logger
public struct OSLogger: LoggerProtocol {
    private let logger: Logger
    
    public init(subsystem: String = "dev.mpy.rBUM", category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        // Debug messages are always private by default as they may contain sensitive information
        logger.debug("[\(file.split(separator: "/").last ?? "", privacy: .public):\(line, privacy: .public)] \(message, privacy: .private)")
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        // Info messages can be public but should be marked private if they contain sensitive data
        logger.info("[\(file.split(separator: "/").last ?? "", privacy: .public):\(line, privacy: .public)] \(message, privacy: .auto)")
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        // Error messages often contain sensitive information and should be private
        logger.error("[\(file.split(separator: "/").last ?? "", privacy: .public):\(line, privacy: .public)] \(message, privacy: .private)")
    }
}

/// Default logger implementation for the current platform
public typealias DefaultLogger = OSLogger
#endif
