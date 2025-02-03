//
//  LoggerFactory.swift
//  Core
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation

/// Factory for creating loggers
public struct LoggerFactory {
    /// Create a new logger for the given category
    /// - Parameter category: Category for the logger
    /// - Returns: A new logger instance
    public static func createLogger(category: String) -> LoggerProtocol {
        return DefaultLogger(category: category)
    }
}
