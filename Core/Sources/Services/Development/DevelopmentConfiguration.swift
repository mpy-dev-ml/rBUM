//
//  DevelopmentConfiguration.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Configuration for development services to simulate various conditions and failures.
/// This struct provides a comprehensive set of options to simulate different
/// error conditions and performance characteristics during development and testing.
///
/// Use this configuration to:
/// - Test error handling paths
/// - Verify timeout handling
/// - Simulate network delays
/// - Test failure recovery mechanisms
/// - Monitor performance metrics
/// - Test resource limits
/// - Validate security boundaries
public struct DevelopmentConfiguration {
    // MARK: - Security Simulation
    
    /// Whether to simulate permission failures during security operations
    public var shouldSimulatePermissionFailures: Bool
    
    /// Whether to simulate bookmark failures when accessing security-scoped resources
    public var shouldSimulateBookmarkFailures: Bool
    
    /// Whether to simulate access failures when attempting to access protected resources
    public var shouldSimulateAccessFailures: Bool
    
    /// Whether to simulate connection failures in network operations
    public var shouldSimulateConnectionFailures: Bool
    
    /// Whether to simulate command timeout failures during long-running operations
    public var shouldSimulateTimeoutFailures: Bool
    
    /// Whether to simulate command execution failures during restic operations
    public var shouldSimulateCommandFailures: Bool
    
    // MARK: - Performance Simulation
    
    /// Artificial delay added to async operations (in seconds)
    /// Used to simulate network latency or slow disk operations
    public var artificialDelay: TimeInterval
    
    /// Simulated command execution time (in seconds)
    /// Used to simulate long-running backup or restore operations
    public var commandExecutionTime: TimeInterval
    
    /// Maximum number of concurrent operations allowed
    public var maxConcurrentOperations: Int
    
    /// Maximum memory usage allowed (in bytes)
    public var maxMemoryUsage: UInt64
    
    /// Maximum disk usage allowed (in bytes)
    public var maxDiskUsage: UInt64
    
    // MARK: - Metrics Configuration
    
    /// Whether to collect detailed performance metrics
    public var shouldCollectMetrics: Bool
    
    /// Maximum number of operations to track in history
    public var maxOperationHistorySize: Int
    
    /// Interval for metrics collection (in seconds)
    public var metricsCollectionInterval: TimeInterval
    
    /// Types of metrics to collect
    public var metricsTypes: Set<MetricType>
    
    // MARK: - Resource Management
    
    /// Whether to simulate resource exhaustion
    public var shouldSimulateResourceExhaustion: Bool
    
    /// Resource limits for simulation
    public var resourceLimits: ResourceLimits
    
    /// Resource warning thresholds
    public var resourceWarningThresholds: ResourceThresholds
    
    // MARK: - Types
    
    /// Types of metrics that can be collected
    public enum MetricType: String, CaseIterable {
        case performance
        case memory
        case disk
        case network
        case security
        case operations
    }
    
    /// Resource limits for simulation
    public struct ResourceLimits {
        public var cpu: Double
        public var memory: UInt64
        public var disk: UInt64
        public var fileDescriptors: Int
        public var networkBandwidth: UInt64
        
        public static let `default` = ResourceLimits(
            cpu: 100.0,
            memory: 1024 * 1024 * 1024,  // 1GB
            disk: 10 * 1024 * 1024 * 1024,  // 10GB
            fileDescriptors: 1000,
            networkBandwidth: 10 * 1024 * 1024  // 10MB/s
        )
    }
    
    /// Resource warning thresholds
    public struct ResourceThresholds {
        public var cpuWarning: Double
        public var memoryWarning: Double
        public var diskWarning: Double
        public var fileDescriptorWarning: Double
        public var networkBandwidthWarning: Double
        
        public static let `default` = ResourceThresholds(
            cpuWarning: 80.0,
            memoryWarning: 80.0,
            diskWarning: 80.0,
            fileDescriptorWarning: 80.0,
            networkBandwidthWarning: 80.0
        )
    }
    
    // MARK: - Initialization
    
    /// Creates a new development configuration with specified simulation parameters.
    ///
    /// - Parameters:
    ///   - shouldSimulatePermissionFailures: If true, simulates permission-related failures
    ///   - shouldSimulateBookmarkFailures: If true, simulates security-scoped bookmark failures
    ///   - shouldSimulateAccessFailures: If true, simulates resource access failures
    ///   - shouldSimulateConnectionFailures: If true, simulates network connection failures
    ///   - shouldSimulateTimeoutFailures: If true, simulates operation timeout failures
    ///   - shouldSimulateCommandFailures: If true, simulates command execution failures
    ///   - artificialDelay: Additional delay in seconds for async operations
    ///   - commandExecutionTime: Simulated execution time in seconds for commands
    ///   - maxConcurrentOperations: Maximum number of concurrent operations
    ///   - maxMemoryUsage: Maximum memory usage in bytes
    ///   - maxDiskUsage: Maximum disk usage in bytes
    ///   - shouldCollectMetrics: Whether to collect detailed metrics
    ///   - maxOperationHistorySize: Maximum size of operation history
    ///   - metricsCollectionInterval: Interval for metrics collection
    ///   - metricsTypes: Types of metrics to collect
    ///   - shouldSimulateResourceExhaustion: Whether to simulate resource exhaustion
    ///   - resourceLimits: Resource limits for simulation
    ///   - resourceWarningThresholds: Resource warning thresholds
    public init(
        shouldSimulatePermissionFailures: Bool = false,
        shouldSimulateBookmarkFailures: Bool = false,
        shouldSimulateAccessFailures: Bool = false,
        shouldSimulateConnectionFailures: Bool = false,
        shouldSimulateTimeoutFailures: Bool = false,
        shouldSimulateCommandFailures: Bool = false,
        artificialDelay: TimeInterval = 0,
        commandExecutionTime: TimeInterval = 0,
        maxConcurrentOperations: Int = 10,
        maxMemoryUsage: UInt64 = 1024 * 1024 * 1024,  // 1GB
        maxDiskUsage: UInt64 = 10 * 1024 * 1024 * 1024,  // 10GB
        shouldCollectMetrics: Bool = true,
        maxOperationHistorySize: Int = 1000,
        metricsCollectionInterval: TimeInterval = 60,
        metricsTypes: Set<MetricType> = Set(MetricType.allCases),
        shouldSimulateResourceExhaustion: Bool = false,
        resourceLimits: ResourceLimits = .default,
        resourceWarningThresholds: ResourceThresholds = .default
    ) {
        self.shouldSimulatePermissionFailures = shouldSimulatePermissionFailures
        self.shouldSimulateBookmarkFailures = shouldSimulateBookmarkFailures
        self.shouldSimulateAccessFailures = shouldSimulateAccessFailures
        self.shouldSimulateConnectionFailures = shouldSimulateConnectionFailures
        self.shouldSimulateTimeoutFailures = shouldSimulateTimeoutFailures
        self.shouldSimulateCommandFailures = shouldSimulateCommandFailures
        self.artificialDelay = artificialDelay
        self.commandExecutionTime = commandExecutionTime
        self.maxConcurrentOperations = maxConcurrentOperations
        self.maxMemoryUsage = maxMemoryUsage
        self.maxDiskUsage = maxDiskUsage
        self.shouldCollectMetrics = shouldCollectMetrics
        self.maxOperationHistorySize = maxOperationHistorySize
        self.metricsCollectionInterval = metricsCollectionInterval
        self.metricsTypes = metricsTypes
        self.shouldSimulateResourceExhaustion = shouldSimulateResourceExhaustion
        self.resourceLimits = resourceLimits
        self.resourceWarningThresholds = resourceWarningThresholds
    }
    
    /// Default configuration with no simulated failures and no delays.
    /// Use this for normal development when simulation of failures is not needed.
    public static let `default` = DevelopmentConfiguration()
    
    /// Configuration for stress testing with all simulations enabled
    public static let stressTest = DevelopmentConfiguration(
        shouldSimulatePermissionFailures: true,
        shouldSimulateBookmarkFailures: true,
        shouldSimulateAccessFailures: true,
        shouldSimulateConnectionFailures: true,
        shouldSimulateTimeoutFailures: true,
        shouldSimulateCommandFailures: true,
        artificialDelay: 1.0,
        commandExecutionTime: 5.0,
        maxConcurrentOperations: 50,
        shouldCollectMetrics: true,
        shouldSimulateResourceExhaustion: true
    )
    
    /// Configuration for performance testing with metrics collection
    public static let performanceTest = DevelopmentConfiguration(
        artificialDelay: 0,
        commandExecutionTime: 0,
        maxConcurrentOperations: 100,
        shouldCollectMetrics: true,
        metricsCollectionInterval: 1.0,
        metricsTypes: [.performance, .memory, .disk, .network]
    )
    
    /// Configuration for security testing
    public static let securityTest = DevelopmentConfiguration(
        shouldSimulatePermissionFailures: true,
        shouldSimulateBookmarkFailures: true,
        shouldSimulateAccessFailures: true,
        shouldSimulateConnectionFailures: true,
        shouldCollectMetrics: true,
        metricsTypes: [.security, .operations]
    )
}

// MARK: - CustomStringConvertible

extension DevelopmentConfiguration: CustomStringConvertible {
    public var description: String {
        """
        DevelopmentConfiguration:
        - Security Simulation:
          • Permission Failures: \(shouldSimulatePermissionFailures)
          • Bookmark Failures: \(shouldSimulateBookmarkFailures)
          • Access Failures: \(shouldSimulateAccessFailures)
          • Connection Failures: \(shouldSimulateConnectionFailures)
          • Timeout Failures: \(shouldSimulateTimeoutFailures)
          • Command Failures: \(shouldSimulateCommandFailures)
        
        - Performance Simulation:
          • Artificial Delay: \(artificialDelay)s
          • Command Execution Time: \(commandExecutionTime)s
          • Max Concurrent Operations: \(maxConcurrentOperations)
          • Max Memory Usage: \(ByteCountFormatter.string(fromByteCount: Int64(maxMemoryUsage), countStyle: .binary))
          • Max Disk Usage: \(ByteCountFormatter.string(fromByteCount: Int64(maxDiskUsage), countStyle: .binary))
        
        - Metrics Configuration:
          • Collect Metrics: \(shouldCollectMetrics)
          • History Size: \(maxOperationHistorySize)
          • Collection Interval: \(metricsCollectionInterval)s
          • Metric Types: \(metricsTypes.map { $0.rawValue }.joined(separator: ", "))
        
        - Resource Management:
          • Simulate Exhaustion: \(shouldSimulateResourceExhaustion)
          • CPU Limit: \(resourceLimits.cpu)%
          • Memory Limit: \(ByteCountFormatter.string(fromByteCount: Int64(resourceLimits.memory), countStyle: .binary))
          • Disk Limit: \(ByteCountFormatter.string(fromByteCount: Int64(resourceLimits.disk), countStyle: .binary))
          • File Descriptor Limit: \(resourceLimits.fileDescriptors)
          • Network Bandwidth Limit: \(ByteCountFormatter.string(fromByteCount: Int64(resourceLimits.networkBandwidth), countStyle: .binary))/s
        """
    }
}
