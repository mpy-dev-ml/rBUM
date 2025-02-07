//
//  LoggerProtocol.swift
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

/// A protocol defining core logging operations for the application.
///
/// `LoggerProtocol` provides a standardised interface for logging at different
/// severity levels, including:
/// - Debug: Detailed information for debugging
/// - Info: General information about system operation
/// - Warning: Potential issues that need attention
/// - Error: Serious problems that need immediate attention
///
/// Each logging method captures contextual information:
/// - Source file
/// - Function name
/// - Line number
/// - Custom message
///
/// Example usage:
/// ```swift
/// class SecurityService {
///     private let logger: LoggerProtocol
///
///     init(logger: LoggerProtocol) {
///         self.logger = logger
///     }
///
///     func validateAccess() {
///         logger.info("Validating access",
///                    file: #file,
///                    function: #function,
///                    line: #line)
///
///         guard isAccessValid else {
///             logger.error("Access validation failed",
///                         file: #file,
///                         function: #function,
///                         line: #line)
///             return
///         }
///     }
/// }
/// ```
///
/// Implementation notes:
/// 1. All methods should be thread-safe
/// 2. Logging should not block the calling thread
/// 3. Failed log attempts should not throw errors
/// 4. Sensitive data should be redacted
public protocol LoggerProtocol {
    /// Logs a debug message with contextual information.
    ///
    /// Debug logs are used for detailed information that is helpful during
    /// development and troubleshooting. These logs should:
    /// - Include detailed state information
    /// - Help track execution flow
    /// - Aid in debugging issues
    /// - Be disabled in production by default
    ///
    /// - Parameters:
    ///   - message: The debug message to log
    ///   - file: The source file where the log was called from
    ///   - function: The function where the log was called from
    ///   - line: The line number where the log was called from
    ///
    /// Example usage:
    /// ```swift
    /// logger.debug("Processing request with ID: \(requestId)",
    ///             file: #file,
    ///             function: #function,
    ///             line: #line)
    /// ```
    func debug(_ message: String, file: String, function: String, line: Int)

    /// Logs an informational message with contextual information.
    ///
    /// Info logs are used for general information about system operation.
    /// These logs should:
    /// - Track normal operation
    /// - Record significant state changes
    /// - Document expected events
    /// - Be concise and meaningful
    ///
    /// - Parameters:
    ///   - message: The informational message to log
    ///   - file: The source file where the log was called from
    ///   - function: The function where the log was called from
    ///   - line: The line number where the log was called from
    ///
    /// Example usage:
    /// ```swift
    /// logger.info("Service initialisation complete",
    ///            file: #file,
    ///            function: #function,
    ///            line: #line)
    /// ```
    func info(_ message: String, file: String, function: String, line: Int)

    /// Logs a warning message with contextual information.
    ///
    /// Warning logs are used for potential issues that need attention.
    /// These logs should:
    /// - Highlight potential problems
    /// - Indicate degraded performance
    /// - Signal approaching limits
    /// - Suggest preventive actions
    ///
    /// - Parameters:
    ///   - message: The warning message to log
    ///   - file: The source file where the log was called from
    ///   - function: The function where the log was called from
    ///   - line: The line number where the log was called from
    ///
    /// Example usage:
    /// ```swift
    /// logger.warning("High memory usage detected: \(memoryUsage)MB",
    ///               file: #file,
    ///               function: #function,
    ///               line: #line)
    /// ```
    func warning(_ message: String, file: String, function: String, line: Int)

    /// Logs an error message with contextual information.
    ///
    /// Error logs are used for serious problems that need immediate attention.
    /// These logs should:
    /// - Detail error conditions
    /// - Include error context
    /// - Aid in diagnosis
    /// - Trigger alerts if necessary
    ///
    /// - Parameters:
    ///   - message: The error message to log
    ///   - file: The source file where the log was called from
    ///   - function: The function where the log was called from
    ///   - line: The line number where the log was called from
    ///
    /// Example usage:
    /// ```swift
    /// logger.error("Failed to save file: \(error.localizedDescription)",
    ///             file: #file,
    ///             function: #function,
    ///             line: #line)
    /// ```
    func error(_ message: String, file: String, function: String, line: Int)
}
