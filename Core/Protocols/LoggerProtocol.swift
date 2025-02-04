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
