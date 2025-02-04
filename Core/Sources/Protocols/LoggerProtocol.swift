//
//  LoggerProtocol.swift
//  Core
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation
import os.log

/// Protocol defining logging operations
public protocol LoggerProtocol {
    /// Log a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called from
    ///   - function: The function where the log was called from
    ///   - line: The line number where the log was called from
    func debug(_ message: String, file: String, function: String, line: Int)
    
    /// Log an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called from
    ///   - function: The function where the log was called from
    ///   - line: The line number where the log was called from
    func info(_ message: String, file: String, function: String, line: Int)
    
    /// Log a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called from
    ///   - function: The function where the log was called from
    ///   - line: The line number where the log was called from
    func warning(_ message: String, file: String, function: String, line: Int)
    
    /// Log an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called from
    ///   - function: The function where the log was called from
    ///   - line: The line number where the log was called from
    func error(_ message: String, file: String, function: String, line: Int)
}

// MARK: - Default Implementations

public extension LoggerProtocol {
    /// Log a debug message with default source location
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, file: file, function: function, line: line)
    }
    
    /// Log an info message with default source location
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, file: file, function: function, line: line)
    }
    
    /// Log a warning message with default source location
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        warning(message, file: file, function: function, line: line)
    }
    
    /// Log an error message with default source location
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message, file: file, function: function, line: line)
    }
    
    /// Log a message with timing information
    func measureAndLog<T>(_ operation: String, level: OSLogType = .debug, block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        switch level {
        case .debug:
            debug("\(operation) completed in \(String(format: "%.3f", duration))s")
        case .info:
            info("\(operation) completed in \(String(format: "%.3f", duration))s")
        case .error:
            error("\(operation) completed in \(String(format: "%.3f", duration))s")
        default:
            info("\(operation) completed in \(String(format: "%.3f", duration))s")
        }
        
        return result
    }
    
    /// Log a message with timing information for async operations
    func measureAndLog<T>(_ operation: String, level: OSLogType = .debug, block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        switch level {
        case .debug:
            debug("\(operation) completed in \(String(format: "%.3f", duration))s")
        case .info:
            info("\(operation) completed in \(String(format: "%.3f", duration))s")
        case .error:
            error("\(operation) completed in \(String(format: "%.3f", duration))s")
        default:
            info("\(operation) completed in \(String(format: "%.3f", duration))s")
        }
        
        return result
    }
}
