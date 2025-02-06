//
//  LoggingService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation
import os.log

/// Protocol for services that require logging capabilities
public protocol LoggingService {
    var logger: LoggerProtocol { get }
}

public extension LoggingService {
    /// Log an operation with timing information
    func logOperation<T>(_ name: String, level: OSLogType = .debug, perform operation: () throws -> T) rethrows -> T {
        let start = Date()
        defer {
            let elapsed = Date().timeIntervalSince(start)
            switch level {
            case .debug:
                logger.debug("\(name) completed in \(elapsed)s",
                           file: #file,
                           function: #function,
                           line: #line)
            case .info:
                logger.info("\(name) completed in \(elapsed)s",
                          file: #file,
                          function: #function,
                          line: #line)
            case .error:
                logger.error("\(name) completed in \(elapsed)s",
                           file: #file,
                           function: #function,
                           line: #line)
            default:
                logger.debug("\(name) completed in \(elapsed)s",
                           file: #file,
                           function: #function,
                           line: #line)
            }
        }
        return try operation()
    }
    
    /// Log an asynchronous operation with timing information
    func logAsyncOperation<T>(_ name: String, level: OSLogType = .debug, perform operation: () async throws -> T) async rethrows -> T {
        let start = Date()
        defer {
            let elapsed = Date().timeIntervalSince(start)
            switch level {
            case .debug:
                logger.debug("\(name) completed in \(elapsed)s",
                           file: #file,
                           function: #function,
                           line: #line)
            case .info:
                logger.info("\(name) completed in \(elapsed)s",
                          file: #file,
                          function: #function,
                          line: #line)
            case .error:
                logger.error("\(name) completed in \(elapsed)s",
                           file: #file,
                           function: #function,
                           line: #line)
            default:
                logger.debug("\(name) completed in \(elapsed)s",
                           file: #file,
                           function: #function,
                           line: #line)
            }
        }
        return try await operation()
    }
}
