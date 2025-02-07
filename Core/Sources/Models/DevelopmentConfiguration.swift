//
//  DevelopmentConfiguration.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 7 February 2025
//

import Foundation

/// Configuration options for development services
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
public struct DevelopmentConfiguration: Equatable, Hashable {
    // MARK: - Properties
    
    /// Whether to simulate bookmark-related failures
    public let shouldSimulateBookmarkFailures: Bool

    /// Whether to simulate access-related failures
    public let shouldSimulateAccessFailures: Bool

    /// Whether to simulate permission-related failures
    public let shouldSimulatePermissionFailures: Bool

    /// Whether to simulate connection-related failures
    public let shouldSimulateConnectionFailures: Bool

    /// Artificial delay in seconds for async operations
    public let artificialDelay: TimeInterval

    /// Maximum simulated memory usage in bytes
    public let maxMemoryUsage: UInt64

    /// Maximum simulated CPU usage percentage (0-100)
    public let maxCPUUsage: Double

    /// Types of metrics to collect during operation
    public let enabledMetrics: Set<MetricType>

    // MARK: - Nested Types

    /// Types of metrics that can be collected
    public enum MetricType: String, Hashable, CaseIterable {
        /// Performance-related metrics (e.g., response times, latency)
        case performance
        /// Memory usage metrics
        case memory
        /// CPU usage metrics
        case cpu
        /// Network-related metrics
        case network
        /// File system operation metrics
        case fileSystem
        /// Security operation metrics
        case security
    }

    // MARK: - Initialization

    /// Creates a new development configuration
    /// - Parameters:
    ///   - shouldSimulateBookmarkFailures: Whether to simulate bookmark failures
    ///   - shouldSimulateAccessFailures: Whether to simulate access failures
    ///   - shouldSimulatePermissionFailures: Whether to simulate permission failures
    ///   - shouldSimulateConnectionFailures: Whether to simulate connection failures
    ///   - artificialDelay: Artificial delay for operations in seconds
    ///   - maxMemoryUsage: Maximum simulated memory usage in bytes
    ///   - maxCPUUsage: Maximum simulated CPU usage percentage (0-100)
    ///   - enabledMetrics: Set of metrics to collect
    public init(
        shouldSimulateBookmarkFailures: Bool = false,
        shouldSimulateAccessFailures: Bool = false,
        shouldSimulatePermissionFailures: Bool = false,
        shouldSimulateConnectionFailures: Bool = false,
        artificialDelay: TimeInterval = 0,
        maxMemoryUsage: UInt64 = UInt64.max,
        maxCPUUsage: Double = 100,
        enabledMetrics: Set<MetricType> = Set(MetricType.allCases)
    ) {
        self.shouldSimulateBookmarkFailures = shouldSimulateBookmarkFailures
        self.shouldSimulateAccessFailures = shouldSimulateAccessFailures
        self.shouldSimulatePermissionFailures = shouldSimulatePermissionFailures
        self.shouldSimulateConnectionFailures = shouldSimulateConnectionFailures
        self.artificialDelay = artificialDelay
        self.maxMemoryUsage = maxMemoryUsage
        self.maxCPUUsage = maxCPUUsage
        self.enabledMetrics = enabledMetrics
    }

    /// Default configuration with no simulated failures
    public static let `default` = DevelopmentConfiguration()
}

// MARK: - CustomStringConvertible

extension DevelopmentConfiguration: CustomStringConvertible {
    public var description: String {
        """
        DevelopmentConfiguration(
            shouldSimulateBookmarkFailures: \(shouldSimulateBookmarkFailures),
            shouldSimulateAccessFailures: \(shouldSimulateAccessFailures),
            shouldSimulatePermissionFailures: \(shouldSimulatePermissionFailures),
            shouldSimulateConnectionFailures: \(shouldSimulateConnectionFailures),
            artificialDelay: \(artificialDelay),
            maxMemoryUsage: \(maxMemoryUsage),
            maxCPUUsage: \(maxCPUUsage),
            enabledMetrics: \(enabledMetrics)
        )
        """
    }
}
