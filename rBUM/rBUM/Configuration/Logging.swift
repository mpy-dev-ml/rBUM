//
//  Logging.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import os

/// Centralized logging configuration for rBUM
enum Logging {
    /// Base subsystem identifier for all loggers
    static let subsystem = "dev.mpy.rBUM"
    
    /// Available logging categories
    enum Category: String {
        case app = "App"
        case appDelegate = "AppDelegate"
        case keychain = "Keychain"
        case repository = "Repository"
        case backup = "Backup"
        case restore = "Restore"
        case settings = "Settings"
        case configuration = "Configuration"
        case storage = "Storage"
        case security = "Security"
        case bookmarkService = "BookmarkService"
        case creation = "Creation"
        case restic = "Restic"
        case snapshots = "Snapshots"
        case process = "Process"
        
        /// Get a logger configured for this category
        var logger: os.Logger {
            os.Logger(subsystem: Logging.subsystem, category: rawValue)
        }
    }
    
    /// Get a logger for a specific category
    static func logger(for category: Category) -> os.Logger {
        category.logger
    }
    
    /// Get a logger with a custom category name
    static func logger(category: String) -> os.Logger {
        os.Logger(subsystem: Logging.subsystem, category: category)
    }
}

// MARK: - Convenience Extensions

extension os.Logger {
    /// Log a message at the debug level
    func debugMessage(_ message: String) {
        log(level: .debug, "\(message)")
    }
    
    /// Log a sensitive message at the debug level
    func debugSensitive(_ message: String) {
        log(level: .debug, "\(message, privacy: .private)")
    }
    
    /// Log a message at the info level
    func infoMessage(_ message: String) {
        log(level: .info, "\(message)")
    }
    
    /// Log a sensitive message at the info level
    func infoSensitive(_ message: String) {
        log(level: .info, "\(message, privacy: .private)")
    }
    
    /// Log a message at the error level
    func errorMessage(_ message: String) {
        log(level: .error, "\(message)")
    }
    
    /// Log a sensitive message at the error level
    func errorSensitive(_ message: String) {
        log(level: .error, "\(message, privacy: .private)")
    }
    
    /// Log a message at the fault level
    func faultMessage(_ message: String) {
        log(level: .fault, "\(message)")
    }
    
    /// Log a sensitive message at the fault level
    func faultSensitive(_ message: String) {
        log(level: .fault, "\(message, privacy: .private)")
    }
    
    /// Log an error with optional context
    func logError(_ error: Error, context: String? = nil) {
        let message = context.map { "\($0): \(error.localizedDescription)" } ?? error.localizedDescription
        errorMessage(message)
    }
}
