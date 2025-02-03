//
//  LoggerFactory.swift
//  Core
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation
import os

/// Factory for creating loggers
public struct LoggerFactory {
    // MARK: - Properties
    
    private let subsystem = "dev.mpy.rBUM"
    
    // MARK: - Public Methods
    
    /// Create a new logger for the given category
    /// - Parameter category: Category for the logger
    /// - Returns: A new logger instance
    public static func createLogger(category: String) -> Logger {
        return Logger(subsystem: "dev.mpy.rBUM", category: category)
    }
}
