import Foundation

/// Represents performance alert thresholds
public struct PerformanceThresholds {
    /// Maximum acceptable memory usage in bytes
    public let maxMemoryUsage: UInt64
    
    /// Maximum acceptable CPU usage percentage
    public let maxCPUUsage: Double
    
    /// Minimum acceptable backup speed in bytes per second
    public let minBackupSpeed: Double
    
    /// Maximum acceptable operation duration in milliseconds
    public let maxOperationDuration: Double
    
    /// Minimum acceptable operation success rate percentage
    public let minSuccessRate: Double
    
    /// Initialises a new PerformanceThresholds instance with default or custom values
    /// - Parameters:
    ///   - maxMemoryUsage: Maximum acceptable memory usage in bytes (default: 1GB)
    ///   - maxCPUUsage: Maximum acceptable CPU usage percentage (default: 80%)
    ///   - minBackupSpeed: Minimum acceptable backup speed in bytes per second (default: 1MB/s)
    ///   - maxOperationDuration: Maximum acceptable operation duration in milliseconds (default: 1 hour)
    ///   - minSuccessRate: Minimum acceptable operation success rate percentage (default: 95%)
    public init(
        maxMemoryUsage: UInt64 = 1024 * 1024 * 1024, // 1GB
        maxCPUUsage: Double = 80.0,
        minBackupSpeed: Double = 1024 * 1024, // 1MB/s
        maxOperationDuration: Double = 3600000, // 1 hour
        minSuccessRate: Double = 95.0
    ) {
        self.maxMemoryUsage = maxMemoryUsage
        self.maxCPUUsage = maxCPUUsage
        self.minBackupSpeed = minBackupSpeed
        self.maxOperationDuration = maxOperationDuration
        self.minSuccessRate = minSuccessRate
    }
}

/// Represents a performance alert
public struct PerformanceAlert: Identifiable {
    /// Unique identifier for the alert
    public let id: UUID
    
    /// Timestamp when the alert was triggered
    public let timestamp: Date
    
    /// Severity level of the alert
    public let severity: AlertSeverity
    
    /// Type of the alert
    public let type: AlertType
    
    /// Human-readable message describing the alert
    public let message: String
    
    /// Additional context information for the alert
    public let context: [String: String]
    
    /// Severity levels for performance alerts
    public enum AlertSeverity {
        /// Warning-level alert
        case warning
        
        /// Critical-level alert
        case critical
    }
    
    /// Types of performance alerts
    public enum AlertType {
        /// High memory usage alert
        case highMemoryUsage
        
        /// High CPU usage alert
        case highCPUUsage
        
        /// Low backup speed alert
        case lowBackupSpeed
        
        /// Long operation duration alert
        case longOperationDuration
        
        /// Low success rate alert
        case lowSuccessRate
        
        /// Human-readable description of the alert type
        var localizedDescription: String {
            switch self {
            case .highMemoryUsage: return "High Memory Usage"
            case .highCPUUsage: return "High CPU Usage"
            case .lowBackupSpeed: return "Low Backup Speed"
            case .longOperationDuration: return "Long Operation Duration"
            case .lowSuccessRate: return "Low Success Rate"
            }
        }
    }
}
