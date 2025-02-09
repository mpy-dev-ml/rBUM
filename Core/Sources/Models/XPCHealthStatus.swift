import Foundation

/// Represents the health status of the XPC service
public struct XPCHealthStatus: Equatable {
    /// Overall health state
    public enum State: Equatable {
        /// Service is healthy and operating normally
        case healthy
        
        /// Service is operating but with degraded performance
        case degraded(String)
        
        /// Service is unhealthy and requires attention
        case unhealthy(String)
        
        /// Service status cannot be determined
        case unknown(String)
    }
    
    /// Current health state
    public let state: State
    
    /// Time of last health check
    public let lastChecked: Date
    
    /// Response time of last health check in seconds
    public let responseTime: TimeInterval
    
    /// Number of consecutive successful health checks
    public let successfulChecks: Int
    
    /// Number of consecutive failed health checks
    public let failedChecks: Int
    
    /// System resources at time of health check
    public let resources: SystemResources
    
    /// Whether the service requires immediate attention
    public var requiresAttention: Bool {
        switch state {
        case .healthy, .unknown:
            return false
        case .degraded:
            return failedChecks >= 2
        case .unhealthy:
            return true
        }
    }
}

/// System resource metrics
public struct SystemResources: Equatable {
    /// CPU usage percentage (0-100)
    public let cpuUsage: Double
    
    /// Memory usage in bytes
    public let memoryUsage: UInt64
    
    /// Available disk space in bytes
    public let availableDiskSpace: UInt64
    
    /// Number of active file handles
    public let activeFileHandles: Int
    
    /// Number of active XPC connections
    public let activeConnections: Int
    
    /// Whether resources are within acceptable limits
    public var isWithinLimits: Bool {
        cpuUsage < 80.0 &&
        memoryUsage < 1_073_741_824 && // 1GB
        availableDiskSpace > 1_073_741_824 && // 1GB
        activeFileHandles < 1000 &&
        activeConnections < 10
    }
}
