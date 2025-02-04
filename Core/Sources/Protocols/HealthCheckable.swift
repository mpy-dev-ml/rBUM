//
//  HealthCheckable.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//


//
//  HealthCheckable.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Protocol for services that can report their health status
public protocol HealthCheckable {
    /// Check if the service is healthy and functioning properly
    /// - Returns: true if the service is healthy, false otherwise
    func isHealthy() -> Bool
}

/// Default implementation for health checking
public extension HealthCheckable where Self: LoggingService {
    func isHealthy() -> Bool {
        // Default implementation assumes the service is healthy
        // Override this in concrete implementations to provide specific health checks
        return true
    }
}
