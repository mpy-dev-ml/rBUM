//
//  Measurable.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Protocol for services that need performance measurement capabilities
public protocol Measurable: LoggingService {
    /// Measure and log the duration of an operation
    /// - Parameters:
    ///   - operation: Name of the operation being measured
    ///   - block: The operation to measure
    /// - Returns: The result of the operation
    func measure<T>(_ operation: String, block: () async throws -> T) async rethrows -> T
}

public extension Measurable {
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
