//
//  HealthCheckable.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Protocol for services that need health check capabilities.
/// This protocol provides a standardised way to monitor and report service health,
/// including detailed health metrics and status information.
@objc public protocol HealthCheckable: NSObjectProtocol {
    /// Current health state of the service (cached value)
    @objc var healthState: HealthState { get }
    
    /// Last time the health check was performed
    @objc var lastHealthCheck: Date? { get }
    
    /// Current health metrics
    @objc var healthMetrics: HealthMetrics { get }
    
    /// Perform a health check
    /// - Returns: Current health state
    /// - Throws: HealthError if check fails
    @objc func performHealthCheck() async throws -> HealthState
    
    /// Update health status asynchronously
    /// This method should be called periodically to update the service's health state
    @objc optional func updateHealthStatus() async
    
    /// Reset health state to unknown
    /// This is useful when service configuration changes
    @objc optional func resetHealthState()
}

/// Represents the possible health states of a service
@objc public enum HealthState: Int {
    case unknown = 0
    case healthy = 1
    case degraded = 2
    case unhealthy = 3
    
    /// String representation of the health state
    public var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .healthy: return "Healthy"
        case .degraded: return "Degraded"
        case .unhealthy: return "Unhealthy"
        }
    }
    
    /// Whether the state indicates the service is operational
    public var isOperational: Bool {
        switch self {
        case .healthy, .degraded: return true
        case .unknown, .unhealthy: return false
        }
    }
}

/// Health-related errors that can occur during health checks
public enum HealthError: LocalizedError {
    case timeout(service: String)
    case connectionFailed(service: String)
    case invalidState(service: String, state: String)
    case dependencyUnavailable(service: String, dependency: String)
    case configurationError(service: String, reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .timeout(let service):
            return "Health check timed out for service: \(service)"
        case .connectionFailed(let service):
            return "Failed to connect to service: \(service)"
        case .invalidState(let service, let state):
            return "Invalid state (\(state)) for service: \(service)"
        case .dependencyUnavailable(let service, let dependency):
            return "Dependency \(dependency) unavailable for service: \(service)"
        case .configurationError(let service, let reason):
            return "Configuration error in service \(service): \(reason)"
        }
    }
}

/// Metrics collected during health checks
@objc public class HealthMetrics: NSObject {
    /// Response time in seconds
    @objc public let responseTime: TimeInterval
    
    /// Memory usage in bytes
    @objc public let memoryUsage: UInt64
    
    /// CPU usage percentage (0-100)
    @objc public let cpuUsage: Double
    
    /// Number of active connections
    @objc public let activeConnections: Int
    
    /// Custom metrics dictionary
    @objc public let customMetrics: [String: NSNumber]
    
    public init(
        responseTime: TimeInterval = 0,
        memoryUsage: UInt64 = 0,
        cpuUsage: Double = 0,
        activeConnections: Int = 0,
        customMetrics: [String: NSNumber] = [:]
    ) {
        self.responseTime = responseTime
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
        self.activeConnections = activeConnections
        self.customMetrics = customMetrics
        super.init()
    }
    
    /// Format metrics as a string
    public override var description: String {
        """
        Response Time: \(String(format: "%.3f", responseTime))s
        Memory Usage: \(ByteCountFormatter.string(
            fromByteCount: Int64(memoryUsage),
            countStyle: .file
        ))
        CPU Usage: \(String(format: "%.1f", cpuUsage))%
        Active Connections: \(activeConnections)
        Custom Metrics: \(customMetrics)
        """
    }
}

/// Default implementation for Swift types
public extension HealthCheckable {
    var healthState: HealthState { .healthy }
    
    var lastHealthCheck: Date? { nil }
    
    var healthMetrics: HealthMetrics { HealthMetrics() }
    
    func performHealthCheck() async throws -> HealthState { .healthy }
    
    func updateHealthStatus() async {}
    
    func resetHealthState() {}
}
