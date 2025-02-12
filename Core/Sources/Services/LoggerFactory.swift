import Foundation
import os.log

/// Factory for creating loggers in the rBUM application.
///
/// The LoggerFactory provides a centralized way to create loggers with consistent configuration
/// across the application. It supports:
/// - Categorized logging domains
/// - Platform-specific logger implementations
/// - Configurable logging options
///
/// Example usage:
/// ```swift
/// // Create a logger with string category
/// let securityLogger = LoggerFactory.createLogger(category: "Security")
///
/// // Configure logging options
/// LoggerFactory.configuration = .init(includeSourceInfo: true)
/// ```
///
/// Implementation notes:
/// 1. Uses platform-specific logger implementations
/// 2. Provides consistent configuration across loggers
/// 3. Supports categorized logging domains
public enum LoggerFactory {
    /// The subsystem identifier for all loggers
    private static let subsystem = "dev.mpy.rBUM"

    // MARK: - Public Methods

    /// Create a new logger for the given category
    /// - Parameter category: String category for the logger
    /// - Returns: A new logger instance conforming to LoggerProtocol
    public static func createLogger(category: String) -> LoggerProtocol {
        #if os(macOS)
            return OSLogger(subsystem: subsystem, category: category)
        #else
            #error("Platform not supported")
        #endif
    }
}
