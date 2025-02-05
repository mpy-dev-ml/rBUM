//
//  HealthCheckable.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Protocol for services that need health check capabilities
public protocol HealthCheckable {
    /// Check if the service is healthy
    var isHealthy: Bool { get }
    
    /// Perform a health check
    /// - Returns: true if healthy, false otherwise
    func performHealthCheck() async -> Bool
}

/// Default implementation
public extension HealthCheckable {
    func performHealthCheck() async -> Bool {
        true // Default implementation returns true
    }
}
