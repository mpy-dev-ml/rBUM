//
//  HealthCheckable.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Protocol for services that need health check capabilities
@objc public protocol HealthCheckable: NSObjectProtocol {
    /// Check if the service is healthy
    var isHealthy: Bool { get }
    
    /// Perform a health check
    /// - Returns: true if healthy, false otherwise
    @objc func performHealthCheck() async -> Bool
}

/// Default implementation for Swift types
public extension HealthCheckable {
    func performHealthCheck() async -> Bool {
        true // Default implementation returns true
    }
}
