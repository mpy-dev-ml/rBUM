//
//  LoggingService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation
import os.log

/// Protocol for services that require logging capabilities.
/// This protocol provides a standardised way to handle logging across the application,
/// ensuring consistent log formatting and level-appropriate messaging.
public protocol LoggingService {
    /// The logger instance used by this service.
    /// This property should be configured during service initialization
    /// and remain constant throughout the service's lifecycle.
    var logger: LoggerProtocol { get }
}

public extension LoggingService {
    /// Logs an operation's execution time and any errors that occur during its execution.
    /// This method wraps an operation with timing information and appropriate error handling,
    /// ensuring consistent logging across all service operations.
    ///
    /// - Parameters:
    ///   - name: The name of the operation being performed
    ///   - level: The logging level to use (default: .debug)
    ///   - operation: The operation to perform and measure
    ///
    /// - Returns: The result of the operation
    /// - Throws: Rethrows any error thrown by the operation
    func logOperation<T>(
        _ name: String,
        level: OSLogType = .debug,
        perform operation: () throws -> T
    ) rethrows -> T {
        let start = Date()
        defer {
            let elapsed = Date().timeIntervalSince(start)
            switch level {
            case .debug:
                logger.debug(
                    "\(name) completed in \(elapsed)s",
                    file: #file,
                    function: #function,
                    line: #line
                )
            case .info:
                logger.info(
                    "\(name) completed in \(elapsed)s",
                    file: #file,
                    function: #function,
                    line: #line
                )
            case .error:
                logger.error(
                    "\(name) completed in \(elapsed)s",
                    file: #file,
                    function: #function,
                    line: #line
                )
            default:
                logger.debug(
                    "\(name) completed in \(elapsed)s",
                    file: #file,
                    function: #function,
                    line: #line
                )
            }
        }
        return try operation()
    }
    
    /// Logs an asynchronous operation's execution time and any errors that occur during its execution.
    /// This method wraps an asynchronous operation with timing information and appropriate error handling,
    /// ensuring consistent logging across all service operations.
    ///
    /// - Parameters:
    ///   - name: The name of the operation being performed
    ///   - level: The logging level to use (default: .debug)
    ///   - operation: The asynchronous operation to perform and measure
    ///
    /// - Returns: The result of the operation
    /// - Throws: Rethrows any error thrown by the operation
    func logAsyncOperation<T>(
        _ name: String,
        level: OSLogType = .debug,
        perform operation: () async throws -> T
    ) async rethrows -> T {
        let start = Date()
        defer {
            let elapsed = Date().timeIntervalSince(start)
            switch level {
            case .debug:
                logger.debug(
                    "\(name) completed in \(elapsed)s",
                    file: #file,
                    function: #function,
                    line: #line
                )
            case .info:
                logger.info(
                    "\(name) completed in \(elapsed)s",
                    file: #file,
                    function: #function,
                    line: #line
                )
            case .error:
                logger.error(
                    "\(name) completed in \(elapsed)s",
                    file: #file,
                    function: #function,
                    line: #line
                )
            default:
                logger.debug(
                    "\(name) completed in \(elapsed)s",
                    file: #file,
                    function: #function,
                    line: #line
                )
            }
        }
        return try await operation()
    }
}
