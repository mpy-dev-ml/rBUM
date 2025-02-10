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
        let logger: os.Logger

        /// The subsystem identifier for this logger
        let subsystem: String

        /// The category identifier for this logger
        let category: String

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
            logger = os.Logger(subsystem: subsystem, category: category)
            super.init()
        }
    }
#endif
