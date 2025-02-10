import Foundation

/// A protocol that defines health monitoring capabilities for services.
///
/// The `HealthCheckable` protocol provides a standardised way to monitor and report service health,
/// including detailed health metrics and status information. It is particularly useful for:
/// - Service availability monitoring
/// - Performance tracking
/// - Resource usage monitoring
/// - Error rate tracking
/// - System diagnostics
///
/// Example usage:
/// ```swift
/// class BackupService: NSObject, HealthCheckable {
///     var healthState: HealthState = .unknown
///     var lastHealthCheck: Date?
///     var healthMetrics = HealthMetrics()
///
///     func performHealthCheck() async throws -> HealthState {
///         // Perform health check logic
///         return .healthy
///     }
/// }
/// ```
@objc public protocol HealthCheckable: NSObjectProtocol {
    /// The current health state of the service.
    ///
    /// This property provides a cached value of the service's health state,
    /// which is updated periodically through health checks.
    @objc var healthState: HealthState { get }

    /// The timestamp of the last performed health check.
    ///
    /// This property helps track when the health state was last verified
    /// and can be used to determine if a new health check is needed.
    @objc var lastHealthCheck: Date? { get }

    /// The current health metrics of the service.
    ///
    /// These metrics provide detailed information about the service's performance
    /// and resource usage, helping identify potential issues or bottlenecks.
    @objc var healthMetrics: HealthMetrics { get }

    /// Performs a comprehensive health check of the service.
    ///
    /// This method should verify:
    /// - Service availability
    /// - Resource usage
    /// - Error rates
    /// - Performance metrics
    /// - System dependencies
    ///
    /// - Returns: The current health state of the service
    /// - Throws: `HealthError` if the health check fails
    @objc func performHealthCheck() async throws -> HealthState

    /// Updates the service's health status asynchronously.
    ///
    /// This method should be called periodically to ensure the health state
    /// remains current. It typically involves:
    /// - Performing a health check
    /// - Updating the health state
    /// - Recording metrics
    /// - Logging status changes
    @objc optional func updateHealthStatus() async

    /// Resets the health state to its initial condition.
    ///
    /// This method should:
    /// - Clear any cached health state
    /// - Reset health metrics
    /// - Clear error counts
    /// - Reset performance measurements
    @objc optional func resetHealthState()

    /// Represents the current health status of a service or component
    public enum HealthStatus {
        /// Service is operating normally
        case healthy
        /// Service is experiencing issues but still functional
        case degraded(String)
        /// Service is not operational
        case unhealthy(String)
    }

    /// Represents a health check result with detailed metrics
    public struct HealthCheckResult {
        /// Current status of the service
        public let status: HealthStatus
        /// Time when the check was performed
        public let timestamp: Date
        /// Duration of the health check in seconds
        public let duration: TimeInterval
        /// Additional metrics collected during the check
        public let metrics: [String: Any]
        /// Detailed message about the health check result
        public let message: String?
    }

    /// Performs a health check on the service or component
    ///
    /// This method performs a comprehensive health check, including:
    /// - Service availability
    /// - Resource usage
    /// - Error rates
    /// - Performance metrics
    /// - System dependencies
    ///
    /// - Returns: A health check result containing status and metrics
    /// - Throws: If the health check operation fails
    public func checkHealth() async throws -> HealthCheckResult

    /// Validates the service's configuration and dependencies
    ///
    /// This method checks the service's configuration and dependencies to ensure they are valid and correctly set up.
    ///
    /// - Returns: A boolean indicating if the validation was successful
    /// - Throws: If the validation process fails
    public func validateConfiguration() async throws -> Bool

    /// Performs cleanup of any resources used by the service
    ///
    /// This method releases any resources held by the service, such as file handles, network connections, or memory.
    ///
    /// - Throws: If the cleanup operation fails
    public func cleanup() async throws
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
        case .unknown: "Unknown"
        case .healthy: "Healthy"
        case .degraded: "Degraded"
        case .unhealthy: "Unhealthy"
        }
    }

    /// Whether the state indicates the service is operational
    public var isOperational: Bool {
        switch self {
        case .healthy,
             .degraded: true
        case .unknown,
             .unhealthy: false
        }
    }
}

/// Health-related errors that can occur during health checks
@objc public enum HealthError: Int, Error {
    case timeout = 1
    case connectionFailed = 2
    case invalidState = 3
    case dependencyUnavailable = 4

    public var errorDescription: String? {
        switch self {
        case .timeout:
            "Service health check timed out"
        case .connectionFailed:
            "Failed to connect to service"
        case .invalidState:
            "Service is in an invalid state"
        case .dependencyUnavailable:
            "Required dependency is unavailable"
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
    override public var description: String {
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

/// Default implementation for Swift types that conform to HealthCheckable.
/// Provides sensible defaults for health monitoring functionality.
public extension HealthCheckable {
    /// The current health state of the service.
    /// Default implementation always returns `.healthy`.
    var healthState: HealthState { .healthy }

    /// The timestamp of the last health check performed.
    /// Default implementation returns `nil` as no checks are performed.
    var lastHealthCheck: Date? { nil }

    /// Current health metrics for the service.
    /// Default implementation returns empty metrics.
    var healthMetrics: HealthMetrics { HealthMetrics() }

    /// Performs a health check on the service.
    /// Default implementation always returns `.healthy`.
    /// - Returns: The current health state
    /// - Throws: HealthError if the check fails
    func performHealthCheck() async throws -> HealthState { .healthy }

    /// Updates the service's health status.
    /// Default implementation does nothing.
    func updateHealthStatus() async {}

    /// Resets the service's health state to its initial value.
    /// Default implementation does nothing.
    func resetHealthState() {}

    /// Performs a comprehensive health check and returns detailed results.
    /// - Returns: A HealthCheckResult containing status, metrics, and diagnostic information
    /// - Throws: HealthError if the check fails
    func checkHealth() async throws -> HealthCheckResult {
        // Default implementation for checkHealth
        HealthCheckResult(
            status: .healthy,
            timestamp: Date(),
            duration: 0,
            metrics: [:],
            message: nil
        )
    }

    /// Validates the service's configuration.
    /// - Returns: True if the configuration is valid, false otherwise
    /// - Throws: HealthError if validation fails
    func validateConfiguration() async throws -> Bool {
        // Default implementation for validateConfiguration
        true
    }

    /// Performs cleanup operations for the service.
    /// - Throws: HealthError if cleanup fails
    func cleanup() async throws {
        // Default implementation for cleanup
    }
}
