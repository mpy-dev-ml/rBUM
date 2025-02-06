//
//  HealthCheckable.swift
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

/// Protocol for services that need health check capabilities
@objc public protocol HealthCheckable: NSObjectProtocol {
    /// Check if the service is healthy (cached value)
    @objc var isHealthy: Bool { get }
    
    /// Perform a health check
    /// - Returns: true if healthy
    /// - Throws: SecurityError if validation fails
    @objc func performHealthCheck() async throws -> Bool
    
    /// Update health status asynchronously
    @objc optional func updateHealthStatus() async
}

/// Default implementation for Swift types
public extension HealthCheckable {
    var isHealthy: Bool { true }
    
    func performHealthCheck() async throws -> Bool { true }
    
    func updateHealthStatus() async {}
}
