import Foundation

/// Metrics for repository lock operations
public struct LockMetrics: Codable, Equatable {
    /// Total number of successful lock acquisitions
    public let successfulAcquisitions: Int
    
    /// Total number of failed lock acquisitions
    public let failedAcquisitions: Int
    
    /// Average lock acquisition time in seconds
    public let averageAcquisitionTime: TimeInterval
    
    /// Maximum lock acquisition time in seconds
    public let maxAcquisitionTime: TimeInterval
    
    /// Total number of stale locks detected
    public let staleLockCount: Int
    
    /// Total number of lock timeouts
    public let timeoutCount: Int
    
    /// Average lock hold time in seconds
    public let averageHoldTime: TimeInterval
    
    /// Maximum lock hold time in seconds
    public let maxHoldTime: TimeInterval
    
    /// Lock contention rate (0-1)
    public let contentionRate: Double
    
    /// Metrics broken down by operation type
    public let operationMetrics: [RepositoryOperation: OperationMetrics]
    
    public init(
        successfulAcquisitions: Int = 0,
        failedAcquisitions: Int = 0,
        averageAcquisitionTime: TimeInterval = 0,
        maxAcquisitionTime: TimeInterval = 0,
        staleLockCount: Int = 0,
        timeoutCount: Int = 0,
        averageHoldTime: TimeInterval = 0,
        maxHoldTime: TimeInterval = 0,
        contentionRate: Double = 0,
        operationMetrics: [RepositoryOperation: OperationMetrics] = [:]
    ) {
        self.successfulAcquisitions = successfulAcquisitions
        self.failedAcquisitions = failedAcquisitions
        self.averageAcquisitionTime = averageAcquisitionTime
        self.maxAcquisitionTime = maxAcquisitionTime
        self.staleLockCount = staleLockCount
        self.timeoutCount = timeoutCount
        self.averageHoldTime = averageHoldTime
        self.maxHoldTime = maxHoldTime
        self.contentionRate = contentionRate
        self.operationMetrics = operationMetrics
    }
}

/// Metrics for a specific operation type
public struct OperationMetrics: Codable, Equatable {
    /// Number of successful operations
    public let successCount: Int
    
    /// Number of failed operations
    public let failureCount: Int
    
    /// Average operation duration in seconds
    public let averageDuration: TimeInterval
    
    /// Maximum operation duration in seconds
    public let maxDuration: TimeInterval
    
    /// Number of times this operation was blocked by other operations
    public let blockCount: Int
    
    public init(
        successCount: Int = 0,
        failureCount: Int = 0,
        averageDuration: TimeInterval = 0,
        maxDuration: TimeInterval = 0,
        blockCount: Int = 0
    ) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.averageDuration = averageDuration
        self.maxDuration = maxDuration
        self.blockCount = blockCount
    }
}
