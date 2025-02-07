//
//  LoggerFactory.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 03/02/2025.
//

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
/// // Create a logger with enum category
/// let backupLogger = LoggerFactory.createLogger(category: .backup)
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
    // MARK: - Public Methods

    /// Create a new logger for the given category
    /// - Parameter category: Category for the logger
    /// - Returns: A new logger instance conforming to LoggerProtocol
    public static func createLogger(category: String) -> LoggerProtocol {
        #if os(macOS)
            return OSLogger(subsystem: Configuration.subsystem, category: category)
        #else
            #error("Platform not supported")
        #endif
    }
}
