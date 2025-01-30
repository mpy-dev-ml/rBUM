//
//  Logging.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import OSLog

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
        
        /// Get a logger configured for this category
        var logger: Logger {
            Logger(subsystem: Logging.subsystem, category: rawValue)
        }
    }
    
    /// Get a logger for a specific category
    static func logger(for category: Category) -> Logger {
        category.logger
    }
    
    /// Get a logger with a custom category name
    static func logger(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}

// MARK: - Convenience Extensions

extension Logger {
    /// Log a message at the debug level
    func debugMessage(_ message: String) {
        debug("\(message)")
    }
    
    /// Log a sensitive message at the debug level
    func debugSensitive(_ message: String) {
        debug("\(message, privacy: .private)")
    }
    
    /// Log a message at the info level
    func infoMessage(_ message: String) {
        info("\(message)")
    }
    
    /// Log a sensitive message at the info level
    func infoSensitive(_ message: String) {
        info("\(message, privacy: .private)")
    }
    
    /// Log a message at the notice level
    func noticeMessage(_ message: String) {
        notice("\(message)")
    }
    
    /// Log a sensitive message at the notice level
    func noticeSensitive(_ message: String) {
        notice("\(message, privacy: .private)")
    }
    
    /// Log a message at the error level
    func errorMessage(_ message: String) {
        error("\(message)")
    }
    
    /// Log a sensitive message at the error level
    func errorSensitive(_ message: String) {
        error("\(message, privacy: .private)")
    }
    
    /// Log a message at the fault level
    func faultMessage(_ message: String) {
        fault("\(message)")
    }
    
    /// Log a sensitive message at the fault level
    func faultSensitive(_ message: String) {
        fault("\(message, privacy: .private)")
    }
    
    /// Log an error with optional context
    func logError(_ error: Error, context: String? = nil) {
        let message: String
        if let context = context {
            message = "\(context): \(error.localizedDescription)"
        } else {
            message = error.localizedDescription
        }
        errorMessage(message)
    }
}
