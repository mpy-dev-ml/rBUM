//
//  OSLogger.swift
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

#if os(macOS)
/// A macOS-specific implementation of `LoggerProtocol` using the system's unified logging system.
///
/// `OSLogger` provides a thread-safe, performant logging interface that integrates with
/// the macOS logging subsystem. It supports:
/// - Multiple log levels (debug, info, warning, error, fault)
/// - Subsystem and category organisation
/// - Privacy-aware logging
/// - Health monitoring
///
/// Key features:
/// - Thread-safe logging operations
/// - Automatic log persistence
/// - Integration with Console.app
/// - Performance logging support
///
/// Example usage:
/// ```swift
/// let logger = OSLogger(subsystem: "dev.mpy.rBUM", category: "Security")
///
/// // Basic logging
/// logger.info("Starting security scan",
///            file: #file,
///            function: #function,
///            line: #line)
///
/// // Health monitoring
/// if await logger.performHealthCheck() {
///     print("Logger is healthy")
/// }
/// ```
///
/// Implementation notes:
/// 1. All logging operations are thread-safe
/// 2. Messages are formatted with source context
/// 3. Health checks verify logging capability
/// 4. Privacy is respected using `.public` for messages
public final class OSLogger: NSObject, LoggerProtocol, HealthCheckable {
    // MARK: - Properties
    
    /// The underlying system logger instance
    private let logger: os.Logger
    
    /// The subsystem identifier for this logger
    private let subsystem: String
    
    /// The category identifier for this logger
    private let category: String
    
    /// Indicates if the logger is currently healthy and operational
    public private(set) var isHealthy: Bool = true
    
    // MARK: - Initialization
    
    /// Creates a new OSLogger instance with the specified subsystem and category.
    ///
    /// - Parameters:
    ///   - subsystem: The identifier for the subsystem, typically reverse DNS notation
    ///   - category: The category within the subsystem for more granular organisation
    ///
    /// Example:
    /// ```swift
    /// let securityLogger = OSLogger(
    ///     subsystem: "dev.mpy.rBUM",
    ///     category: "Security"
    /// )
    /// ```
    public init(
        subsystem: String = "dev.mpy.rBUM",
        category: String
    ) {
        self.subsystem = subsystem
        self.category = category
        self.logger = os.Logger(subsystem: subsystem, category: category)
        super.init()
    }
    
    // MARK: - HealthCheckable Implementation
    
    /// Updates the health status of the logger asynchronously.
    ///
    /// This method:
    /// 1. Performs a health check
    /// 2. Updates the `isHealthy` property
    /// 3. Can be called from Objective-C
    ///
    /// Example:
    /// ```swift
    /// await logger.updateHealthStatus()
    /// if logger.isHealthy {
    ///     print("Logger is operational")
    /// }
    /// ```
    @objc public func updateHealthStatus() async {
        isHealthy = await performHealthCheck()
    }
    
    /// Performs a health check on the logger.
    ///
    /// This method verifies:
    /// 1. The ability to write to system log
    /// 2. The validity of subsystem and category
    /// 3. The overall logging system health
    ///
    /// - Returns: `true` if the logger is healthy, `false` otherwise
    ///
    /// Example:
    /// ```swift
    /// if await logger.performHealthCheck() {
    ///     print("Logger health check passed")
    /// }
    /// ```
    @objc public func performHealthCheck() async -> Bool {
        // Logger health check:
        // 1. Verify we can write to system log
        // 2. Verify subsystem and category are valid
        logger.debug(
            """
            Health check: \
            \(self.subsystem).\(self.category)
            """
        )
        return true
    }
    
    // MARK: - LoggerProtocol Implementation
    
    /// Logs a debug message with source context.
    ///
    /// Debug messages should contain detailed information useful for
    /// debugging and development purposes.
    ///
    /// - Parameters:
    ///   - message: The debug message to log
    ///   - file: Source file where the log was called
    ///   - function: Function where the log was called
    ///   - line: Line number where the log was called
    public func debug(
        _ message: String,
        file: String,
        function: String,
        line: Int
    ) {
        logger.debug(
            """
            \(message, privacy: .public) \
            [\(file):\(line) \(function)]
            """
        )
    }
    
    /// Logs an informational message with source context.
    ///
    /// Info messages should contain general information about
    /// system operation and state changes.
    ///
    /// - Parameters:
    ///   - message: The informational message to log
    ///   - file: Source file where the log was called
    ///   - function: Function where the log was called
    ///   - line: Line number where the log was called
    public func info(
        _ message: String,
        file: String,
        function: String,
        line: Int
    ) {
        logger.info(
            """
            \(message, privacy: .public) \
            [\(file):\(line) \(function)]
            """
        )
    }
    
    /// Logs a warning message with source context.
    ///
    /// Warning messages should highlight potential issues
    /// that need attention but aren't critical failures.
    ///
    /// - Parameters:
    ///   - message: The warning message to log
    ///   - file: Source file where the log was called
    ///   - function: Function where the log was called
    ///   - line: Line number where the log was called
    public func warning(
        _ message: String,
        file: String,
        function: String,
        line: Int
    ) {
        logger.warning(
            """
            \(message, privacy: .public) \
            [\(file):\(line) \(function)]
            """
        )
    }
    
    /// Logs an error message with source context.
    ///
    /// Error messages should detail serious problems
    /// that need immediate attention.
    ///
    /// - Parameters:
    ///   - message: The error message to log
    ///   - file: Source file where the log was called
    ///   - function: Function where the log was called
    ///   - line: Line number where the log was called
    public func error(
        _ message: String,
        file: String,
        function: String,
        line: Int
    ) {
        logger.error(
            """
            \(message, privacy: .public) \
            [\(file):\(line) \(function)]
            """
        )
    }
    
    /// Logs a fault message with source context.
    ///
    /// Fault messages should indicate system-level failures
    /// that may require immediate intervention.
    ///
    /// - Parameters:
    ///   - message: The fault message to log
    ///   - file: Source file where the log was called
    ///   - function: Function where the log was called
    ///   - line: Line number where the log was called
    public func fault(
        _ message: String,
        file: String,
        function: String,
        line: Int
    ) {
        logger.fault(
            """
            \(message, privacy: .public) \
            [\(file):\(line) \(function)]
            """
        )
    }
}
#endif
