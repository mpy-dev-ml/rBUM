import Foundation

/// Represents a single performance metric measurement
public struct MetricMeasurement {
    /// Name of the metric
    public let name: String
    
    /// Measured value
    public let value: Double
    
    /// Unit of measurement
    public let unit: MetricUnit
    
    /// Timestamp of measurement
    public let timestamp: Date
    
    /// Additional context about the measurement
    public let metadata: [String: String]?
}

/// Represents a monitored operation
public struct MonitoredOperation {
    /// Unique identifier for the operation
    public let id: UUID
    
    /// Name of the operation
    public let name: String
    
    /// Start time of the operation
    public let startTime: Date
    
    /// End time of the operation
    public let endTime: Date?
    
    /// Duration in milliseconds
    public var duration: Double? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime) * 1000
    }
    
    /// Status of the operation
    public let status: OperationStatus?
    
    /// Additional context about the operation
    public let metadata: [String: String]?
}

/// Comprehensive performance report
public struct PerformanceReport {
    /// Time period of the report
    public let period: DateInterval
    
    /// List of operations during this period
    public let operations: [MonitoredOperation]
    
    /// List of metrics recorded during this period
    public let metrics: [MetricMeasurement]
    
    /// Summary statistics
    public let statistics: PerformanceStatistics
}

/// Statistical summary of performance metrics
public struct PerformanceStatistics {
    /// Average operation duration in milliseconds
    public let averageOperationDuration: Double
    
    /// Success rate of operations (percentage)
    public let operationSuccessRate: Double
    
    /// Peak memory usage in bytes
    public let peakMemoryUsage: UInt64
    
    /// Average CPU usage percentage
    public let averageCPUUsage: Double
    
    /// Peak CPU usage percentage
    public let peakCPUUsage: Double
    
    /// Average backup speed in bytes per second
    public let averageBackupSpeed: Double
    
    /// Total number of operations
    public let totalOperations: Int
    
    /// Number of failed operations
    public let failedOperations: Int
}
