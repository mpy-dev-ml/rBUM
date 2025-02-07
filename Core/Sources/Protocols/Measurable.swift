//
//  Measurable.swift
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

/// Protocol for services that need performance measurement capabilities.
/// This protocol extends LoggingService to provide standardised performance
/// measurement and logging functionality for async operations.
///
/// Conforming types will be able to measure and log the duration of
/// asynchronous operations, which is particularly useful for:
/// - Performance monitoring
/// - Identifying bottlenecks
/// - Debugging slow operations
/// - Gathering metrics for optimisation
public protocol Measurable: LoggingService {
    /// Measure and log the duration of an asynchronous operation.
    ///
    /// - Parameters:
    ///   - operation: A descriptive name of the operation being measured
    ///   - block: The asynchronous operation to measure
    ///
    /// - Returns: The result of the operation
    /// - Throws: Rethrows any error thrown by the operation block
    func measure<T>(_ operation: String, block: () async throws -> T) async rethrows -> T
}

/// Default implementation of the Measurable protocol
public extension Measurable {
    /// Measures and logs the duration of an asynchronous operation.
    /// The duration is logged at the info level with two decimal places precision.
    ///
    /// - Parameters:
    ///   - operation: A descriptive name of the operation being measured
    ///   - block: The asynchronous operation to measure
    ///
    /// - Returns: The result of the operation
    /// - Throws: Rethrows any error thrown by the operation block
    func measure<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let start = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(start)
        logger.info("\(operation) completed in \(String(format: "%.2f", duration))s",
                   file: #file,
                   function: #function,
                   line: #line)
        return result
    }
}
