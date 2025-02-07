import Foundation
import os.log

#if os(macOS)
extension OSLogger {
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
