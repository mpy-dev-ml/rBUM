//
//  OSLogger.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation
import os.log

#if os(macOS)
/// OSLogger implementation of LoggerProtocol using os.Logger
public final class OSLogger: LoggerProtocol, HealthCheckable {
    public var isHealthy: Bool
    
    public func performHealthCheck() async -> Bool {
        <#code#>
    }
    
    // MARK: - Properties
    private let logger: os.Logger
    private let subsystem: String
    private let category: String
    
    // MARK: - Initialization
    public init(subsystem: String = "dev.mpy.rBUM", category: String) {
        self.subsystem = subsystem
        self.category = category
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }
    
    // MARK: - HealthCheckable Implementation
    public func isHealthy() -> Bool {
        true // Logger is typically always healthy unless system-level issues
    }
    
    // MARK: - LoggerProtocol Implementation
    public func debug(_ message: String, file: String, function: String, line: Int) {
        logger.debug("\(message, privacy: .public) [\(file):\(line) \(function)]")
    }
    
    public func info(_ message: String, file: String, function: String, line: Int) {
        logger.info("\(message, privacy: .public) [\(file):\(line) \(function)]")
    }
    
    public func warning(_ message: String, file: String, function: String, line: Int) {
        logger.warning("\(message, privacy: .public) [\(file):\(line) \(function)]")
    }
    
    public func error(_ message: String, file: String, function: String, line: Int) {
        logger.error("\(message, privacy: .public) [\(file):\(line) \(function)]")
    }
    
    public func fault(_ message: String, file: String, function: String, line: Int) {
        logger.fault("\(message, privacy: .public) [\(file):\(line) \(function)]")
    }
}
#endif
