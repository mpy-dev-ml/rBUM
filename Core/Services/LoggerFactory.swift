//
//  LoggerFactory.swift
//  Core
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation
import os.log

/// Factory for creating loggers
public struct LoggerFactory {
    // MARK: - Properties
    
    private static let subsystem = "dev.mpy.rBUM"
    
    // MARK: - Public Methods
    
    /// Create a new logger for the given category
    /// - Parameter category: Category for the logger
    /// - Returns: A new logger instance conforming to LoggerProtocol
    public static func createLogger(category: String) -> LoggerProtocol {
        #if os(macOS)
        return OSLogger(subsystem: subsystem, category: category)
        #else
        #error("Platform not supported")
        #endif
    }
}
