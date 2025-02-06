//
//  ServiceLifecycle.swift
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

/// Service lifecycle states
public enum ServiceState {
    case uninitialized
    case initializing
    case ready
    case error(Error)
    case shutdown
}

/// Protocol for services that need lifecycle management
public protocol LifecycleManaged {
    var state: ServiceState { get }
    func initialize() async throws
    func shutdown() async
}

/// Base implementation of lifecycle management
public extension LifecycleManaged where Self: LoggingService {
    func initialize() async throws {
        logger.info("Initialising service...",
                   file: #file,
                   function: #function,
                   line: #line)
        // Override in concrete implementations
    }
    
    func shutdown() async {
        logger.info("Shutting down service...",
                   file: #file,
                   function: #function,
                   line: #line)
        // Override in concrete implementations
    }
}
