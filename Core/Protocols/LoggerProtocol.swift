//
//  LoggerProtocol.swift
//  Core
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation

/// Privacy level for logged messages
public enum LogPrivacy {
    /// Public information that can be freely logged
    case `public`
    /// Private information that should be redacted in logs
    case `private`
    /// Sensitive information that should be carefully handled
    case sensitive
}

/// Protocol for logging messages with different privacy levels
public protocol LoggerProtocol {
    /// Log a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - privacy: Privacy level for the message
    func debug(_ message: String, privacy: LogPrivacy)
    
    /// Log an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - privacy: Privacy level for the message
    func info(_ message: String, privacy: LogPrivacy)
    
    /// Log an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - privacy: Privacy level for the message
    func error(_ message: String, privacy: LogPrivacy)
}

#if os(macOS)
import os

/// macOS-specific logger implementation using os.Logger
public struct OSLogger: LoggerProtocol {
    private let logger: Logger
    
    public init(subsystem: String = "dev.mpy.rBUM", category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    public func debug(_ message: String, privacy: LogPrivacy) {
        logger.debug("\(message, privacy: privacy.toOSLogPrivacy)")
    }
    
    public func info(_ message: String, privacy: LogPrivacy) {
        logger.info("\(message, privacy: privacy.toOSLogPrivacy)")
    }
    
    public func error(_ message: String, privacy: LogPrivacy) {
        logger.error("\(message, privacy: privacy.toOSLogPrivacy)")
    }
}

private extension LogPrivacy {
    var toOSLogPrivacy: OSLogPrivacy {
        switch self {
        case .public:
            return .public
        case .private:
            return .private
        case .sensitive:
            return .private // os.Logger doesn't have a 'sensitive' level
        }
    }
}
#endif

/// Default logger implementation for the current platform
public typealias DefaultLogger = OSLogger
