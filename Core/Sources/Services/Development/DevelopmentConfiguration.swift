//
//  DevelopmentConfiguration.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// A configuration struct for controlling development and testing behaviours.
///
/// `DevelopmentConfiguration` provides a comprehensive set of options to simulate
/// various conditions and failures during development and testing. This enables:
/// - Thorough testing of error handling paths
/// - Verification of timeout handling
/// - Simulation of network delays and failures
/// - Testing of failure recovery mechanisms
/// - Performance monitoring and metrics collection
/// - Resource limit testing
/// - Security boundary validation
///
/// Example usage:
/// ```swift
/// let config = DevelopmentConfiguration(
///     shouldSimulatePermissionFailures: true,
///     shouldSimulateBookmarkFailures: false,
///     artificialDelay: 1.0,
///     shouldCollectMetrics: true
/// )
/// ```
public struct DevelopmentConfiguration {
    // MARK: - Security Simulation
    
    /// Controls whether permission-related failures should be simulated.
    ///
    /// When enabled, this will cause security operations to randomly fail with
    /// permission-related errors, helping test error handling paths.
    public var shouldSimulatePermissionFailures: Bool
    
    /// Controls whether bookmark-related failures should be simulated.
    ///
    /// When enabled, this will cause security-scoped bookmark operations to
    /// randomly fail, helping test bookmark error handling.
    public var shouldSimulateBookmarkFailures: Bool
    
    /// Controls whether access-related failures should be simulated.
    ///
    /// When enabled, this will cause resource access operations to randomly
    /// fail, helping test access error handling.
    public var shouldSimulateAccessFailures: Bool
    
    // MARK: - Network Simulation
    
    /// Controls whether network connection failures should be simulated.
    ///
    /// When enabled, this will cause network operations to randomly fail,
    /// helping test network error handling and recovery.
    public var shouldSimulateConnectionFailures: Bool
    
    /// Controls whether timeout failures should be simulated.
    ///
    /// When enabled, this will cause operations to randomly time out,
    /// helping test timeout handling and recovery.
    public var shouldSimulateTimeoutFailures: Bool
    
    /// The artificial delay to add to asynchronous operations.
    ///
    /// This delay is added to all async operations to simulate network
    /// latency or processing time. Specified in seconds.
    public var artificialDelay: TimeInterval
    
    // MARK: - Resource Management
    
    /// Controls whether command execution failures should be simulated.
    ///
    /// When enabled, this will cause command executions to randomly fail,
    /// helping test command error handling.
    public var shouldSimulateCommandFailures: Bool
    
    /// The simulated execution time for commands.
    ///
    /// This value determines how long simulated commands will take to execute,
    /// helping test long-running operation handling. Specified in seconds.
    public var commandExecutionTime: TimeInterval
    
    /// The maximum number of concurrent operations allowed.
    ///
    /// This limit helps test resource contention and queue management.
    public var maxConcurrentOperations: Int
    
    /// The maximum memory usage allowed in bytes.
    ///
    /// This limit helps test memory pressure handling and resource management.
    public var maxMemoryUsage: UInt64
    
    /// The maximum disk usage allowed in bytes.
    ///
    /// This limit helps test disk space management and cleanup procedures.
    public var maxDiskUsage: UInt64
    
    // MARK: - Metrics Collection
    
    /// Controls whether detailed metrics should be collected.
    ///
    /// When enabled, the system will collect and store detailed metrics about
    /// various operations and resource usage.
    public var shouldCollectMetrics: Bool
    
    /// The maximum size of the operation history.
    ///
    /// This determines how many past operations are kept in memory for
    /// analysis and debugging.
    public var maxOperationHistorySize: Int
    
    /// The interval at which metrics are collected.
    ///
    /// This determines how frequently metrics are sampled and stored.
    /// Specified in seconds.
    public var metricsCollectionInterval: TimeInterval
    
    /// The types of metrics to collect.
    ///
    /// This set determines which categories of metrics should be collected
    /// and stored for analysis.
    public var metricsTypes: Set<MetricType>
    
    /// Controls whether resource exhaustion should be simulated.
    ///
    /// When enabled, this will simulate various resource pressure scenarios
    /// to test system behaviour under resource constraints.
    public var shouldSimulateResourceExhaustion: Bool
    
    /// The resource limits to enforce during simulation.
    ///
    /// These limits define the maximum resources available to the system
    /// during testing.
    public var resourceLimits: ResourceLimits
    
    /// The resource thresholds for generating warnings.
    ///
    /// These thresholds determine when warning events should be generated
    /// for resource usage.
    public var resourceWarningThresholds: ResourceThresholds
    
    /// The types of metrics that can be collected.
    ///
    /// These metric types cover different aspects of system performance
    /// and resource usage.
    public enum MetricType: String, CaseIterable {
        /// Performance-related metrics (e.g., response times, latency)
        case performance
        /// Memory usage metrics
        case memory
        /// Disk usage and I/O metrics
        case disk
        /// Network usage and performance metrics
        case network
        /// Security-related metrics
        case security
        /// Operation execution metrics
        case operations
    }
    
    /// Resource limits for development and testing simulation.
    ///
    /// This struct defines the maximum resource limits that should be enforced
    /// during development and testing. These limits help simulate resource
    /// constraints and test system behaviour under pressure.
    public struct ResourceLimits {
        /// Maximum CPU usage percentage (0-100)
        public var cpu: Double
        
        /// Maximum memory usage in bytes
        public var memory: UInt64
        
        /// Maximum disk usage in bytes
        public var disk: UInt64
        
        /// Maximum number of open file descriptors
        public var fileDescriptors: Int
        
        /// Maximum network bandwidth in bytes per second
        public var networkBandwidth: UInt64
        
        /// Default resource limits suitable for most development scenarios
        public static let `default` = ResourceLimits(
            cpu: 100.0,
            memory: 1024 * 1024 * 1024,  // 1GB
            disk: 10 * 1024 * 1024 * 1024,  // 10GB
            fileDescriptors: 1000,
            networkBandwidth: 10 * 1024 * 1024  // 10MB/s
        )
    }
    
    /// Resource warning thresholds for development and testing.
    ///
    /// This struct defines the thresholds at which resource usage warnings
    /// should be generated. These thresholds help identify potential resource
    /// issues before they become critical.
    public struct ResourceThresholds {
        /// CPU usage percentage that triggers a warning (0-100)
        public var cpuWarning: Double
        
        /// Memory usage percentage that triggers a warning (0-100)
        public var memoryWarning: Double
        
        /// Disk usage percentage that triggers a warning (0-100)
        public var diskWarning: Double
        
        /// File descriptor usage percentage that triggers a warning (0-100)
        public var fileDescriptorWarning: Double
        
        /// Network bandwidth usage percentage that triggers a warning (0-100)
        public var networkBandwidthWarning: Double
        
        /// Default warning thresholds suitable for most development scenarios.
        ///
        /// These thresholds are set to 80% of the maximum resource limits,
        /// providing early warning of potential resource issues.
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
