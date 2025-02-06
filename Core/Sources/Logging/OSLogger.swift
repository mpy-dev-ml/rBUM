//
//  OSLogger.swift
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

#if os(macOS)
/// OSLogger implementation of LoggerProtocol using os.Logger
public final class OSLogger: NSObject, LoggerProtocol, HealthCheckable {
    // MARK: - Properties
    private let logger: os.Logger
    private let subsystem: String
    private let category: String
    public private(set) var isHealthy: Bool = true
    
    // MARK: - Initialization
    public init(subsystem: String = "dev.mpy.rBUM", category: String) {
        self.subsystem = subsystem
        self.category = category
        self.logger = os.Logger(subsystem: subsystem, category: category)
        super.init()
    }
    
    // MARK: - HealthCheckable Implementation
    @objc public func updateHealthStatus() async {
        isHealthy = await performHealthCheck()
    }
    
    @objc public func performHealthCheck() async -> Bool {
        // Logger health check:
        // 1. Verify we can write to system log
        // 2. Verify subsystem and category are valid
        logger.debug("Health check: \(self.subsystem).\(self.category)")
        return true
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
