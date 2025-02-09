import Foundation

/// Protocol defining performance monitoring capabilities
public protocol PerformanceMonitorProtocol {
    /// Start monitoring a specific operation
    /// - Parameters:
    ///   - operation: Name of the operation being monitored
    ///   - metadata: Additional context about the operation
    /// - Returns: A unique identifier for the operation
    func startOperation(_ operation: String, metadata: [String: String]?) async -> UUID
    
    /// End monitoring for an operation
    /// - Parameters:
    ///   - operationId: The operation's unique identifier
    ///   - status: Final status of the operation
    func endOperation(_ operationId: UUID, status: OperationStatus) async
    
    /// Record a specific metric
    /// - Parameters:
    ///   - name: Name of the metric
    ///   - value: Value to record
    ///   - unit: Unit of measurement
    ///   - metadata: Additional context about the metric
    func recordMetric(_ name: String, value: Double, unit: MetricUnit, metadata: [String: String]?) async
    
    /// Get performance report for a time period
    /// - Parameters:
    ///   - startDate: Start of the period
    ///   - endDate: End of the period
    /// - Returns: Performance report for the specified period
    func getPerformanceReport(from startDate: Date, to endDate: Date) async -> PerformanceReport
}

/// Units for performance metrics
public enum MetricUnit {
    /// Size in bytes
    case bytes
    /// Time duration in milliseconds
    case milliseconds
    /// Percentage value
    case percentage
    /// Numeric count
    case count
    /// Data transfer rate in bytes per second
    case bytesPerSecond
    
    /// String representation of the unit
    var description: String {
        switch self {
        case .bytes: return "bytes"
        case .milliseconds: return "ms"
        case .percentage: return "%"
        case .count: return "count"
        case .bytesPerSecond: return "B/s"
        }
    }
}

/// Status of a monitored operation
public enum OperationStatus {
    /// Operation completed successfully
    case completed
    /// Operation failed with an error
    case failed(Error)
    /// Operation was cancelled
    case cancelled
}
