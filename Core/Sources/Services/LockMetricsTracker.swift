import Foundation

/// Represents a lock acquisition attempt result
public struct LockAttemptResult {
    /// Whether the lock was successfully acquired
    public let success: Bool
    /// Duration of the attempt in seconds
    public let duration: TimeInterval
    /// Error that occurred during the attempt, if any
    public let error: Error?
    /// Time when the attempt was made
    public let timestamp: Date
}

/// Service for tracking repository lock metrics
public final class LockMetricsTracker {
    private let queue = DispatchQueue(label: "com.rbum.lockmetrics")
    private var metrics: [String: RepositoryMetrics] = [:]
    private let logger: LoggerProtocol
    
    /// Initialises a new lock metrics tracker
    /// - Parameter logger: Logger for recording metric events
    public init(logger: LoggerProtocol) {
        self.logger = logger
    }
    
    /// Represents mutable operation metrics
    private struct MutableOperationMetrics {
        var successCount: Int = 0
        var failureCount: Int = 0
        var durations: [TimeInterval] = []
        var blockCount: Int = 0
    }
    
    private struct RepositoryMetrics {
        var successfulAcquisitions: Int = 0
        var failedAcquisitions: Int = 0
        var acquisitionTimes: [TimeInterval] = []
        var staleLockCount: Int = 0
        var timeoutCount: Int = 0
        var holdTimes: [TimeInterval] = []
        var contentions: Int = 0
        var totalAttempts: Int = 0
        var operationMetrics: [RepositoryOperation: MutableOperationMetrics] = [:]
        
        func toLockMetrics() -> LockMetrics {
            let operationMetrics = Dictionary(
                uniqueKeysWithValues: self.operationMetrics.map { op, metrics in
                    (op, OperationMetrics(
                        successCount: metrics.successCount,
                        failureCount: metrics.failureCount,
                        averageDuration: metrics.durations.isEmpty ? 0 : 
                            metrics.durations.reduce(0, +) / Double(metrics.durations.count),
                        maxDuration: metrics.durations.max() ?? 0,
                        blockCount: metrics.blockCount
                    ))
                }
            )
            
            let avgAcquisitionTime = acquisitionTimes.isEmpty ? 0 : 
                acquisitionTimes.reduce(0, +) / Double(acquisitionTimes.count)
            
            let avgHoldTime = holdTimes.isEmpty ? 0 : 
                holdTimes.reduce(0, +) / Double(holdTimes.count)
            
            return LockMetrics(
                successfulAcquisitions: successfulAcquisitions,
                failedAcquisitions: failedAcquisitions,
                averageAcquisitionTime: avgAcquisitionTime,
                maxAcquisitionTime: acquisitionTimes.max() ?? 0,
                staleLockCount: staleLockCount,
                timeoutCount: timeoutCount,
                averageHoldTime: avgHoldTime,
                maxHoldTime: holdTimes.max() ?? 0,
                contentionRate: totalAttempts == 0 ? 0 : Double(contentions) / Double(totalAttempts),
                operationMetrics: operationMetrics
            )
        }
    }
    
    /// Records a successful lock acquisition
    public func recordAcquisition(
        repository: Repository,
        operation: RepositoryOperation,
        acquisitionTime: TimeInterval
    ) {
        queue.async {
            var repoMetrics = self.metrics[repository.path] ?? RepositoryMetrics()
            repoMetrics.successfulAcquisitions += 1
            repoMetrics.acquisitionTimes.append(acquisitionTime)
            repoMetrics.totalAttempts += 1
            
            var opMetrics = repoMetrics.operationMetrics[operation] ?? MutableOperationMetrics()
            opMetrics.successCount += 1
            repoMetrics.operationMetrics[operation] = opMetrics
            
            self.metrics[repository.path] = repoMetrics
        }
    }
    
    /// Records a failed lock acquisition
    public func recordFailedAcquisition(
        repository: Repository,
        operation: RepositoryOperation,
        reason: LockError
    ) {
        queue.async {
            var repoMetrics = self.metrics[repository.path] ?? RepositoryMetrics()
            repoMetrics.failedAcquisitions += 1
            repoMetrics.totalAttempts += 1
            
            switch reason {
            case .timeout:
                repoMetrics.timeoutCount += 1
            case .alreadyLocked:
                repoMetrics.contentions += 1
            default:
                break
            }
            
            var opMetrics = repoMetrics.operationMetrics[operation] ?? MutableOperationMetrics()
            opMetrics.failureCount += 1
            if case .alreadyLocked = reason {
                opMetrics.blockCount += 1
            }
            repoMetrics.operationMetrics[operation] = opMetrics
            
            self.metrics[repository.path] = repoMetrics
        }
    }
    
    /// Records a lock release
    public func recordRelease(
        repository: Repository,
        operation: RepositoryOperation,
        holdTime: TimeInterval
    ) {
        queue.async {
            var repoMetrics = self.metrics[repository.path] ?? RepositoryMetrics()
            repoMetrics.holdTimes.append(holdTime)
            
            var opMetrics = repoMetrics.operationMetrics[operation] ?? MutableOperationMetrics()
            opMetrics.durations.append(holdTime)
            repoMetrics.operationMetrics[operation] = opMetrics
            
            self.metrics[repository.path] = repoMetrics
        }
    }
    
    /// Records detection of a stale lock
    public func recordStaleLock(repository: Repository) {
        queue.async {
            var repoMetrics = self.metrics[repository.path] ?? RepositoryMetrics()
            repoMetrics.staleLockCount += 1
            self.metrics[repository.path] = repoMetrics
        }
    }
    
    /// Gets the current metrics for a repository
    public func getMetrics(for repository: Repository) -> LockMetrics {
        queue.sync {
            return metrics[repository.path]?.toLockMetrics() ?? LockMetrics()
        }
    }
    
    /// Gets metrics for all repositories
    public func getAllMetrics() -> [String: LockMetrics] {
        queue.sync {
            return Dictionary(uniqueKeysWithValues: metrics.map { path, metrics in
                (path, metrics.toLockMetrics())
            })
        }
    }
    
    /// Resets metrics for a repository
    public func resetMetrics(for repository: Repository) {
        queue.async {
            metrics.removeValue(forKey: repository.path)
        }
    }
    
    /// Resets all metrics
    public func resetAllMetrics() {
        queue.async {
            metrics.removeAll()
        }
    }
    
    /// Records a lock attempt result
    /// - Parameters:
    ///   - lockId: Identifier for the lock
    ///   - success: Whether the lock attempt was successful
    ///   - waitTime: Time spent waiting for the lock
    public func recordLockAttempt(
        lockId: String,
        success: Bool,
        waitTime: TimeInterval
    ) {
        if let existing = metrics[lockId] {
            let attempts = existing.totalAttempts + 1
            let successes = existing.successfulAcquisitions + (success ? 1 : 0)
            let failures = existing.failedAcquisitions + (success ? 0 : 1)
            let totalTime = existing.acquisitionTimes.reduce(0, +) + waitTime
            let avgTime = totalTime / Double(attempts)
            let maxTime = existing.acquisitionTimes.max() ?? 0
            
            var repoMetrics = existing
            repoMetrics.totalAttempts = attempts
            repoMetrics.successfulAcquisitions = successes
            repoMetrics.failedAcquisitions = failures
            repoMetrics.acquisitionTimes.append(waitTime)
            
            metrics[lockId] = repoMetrics
        } else {
            var repoMetrics = RepositoryMetrics()
            repoMetrics.totalAttempts = 1
            repoMetrics.successfulAcquisitions = success ? 1 : 0
            repoMetrics.failedAcquisitions = success ? 0 : 1
            repoMetrics.acquisitionTimes.append(waitTime)
            
            metrics[lockId] = repoMetrics
        }
        
        logger.log(
            "Lock attempt for '\(lockId)': success=\(success), waitTime=\(waitTime)s",
            level: .debug
        )
    }
    
    /// Helper function to calculate average wait time
    private func calculateAverageWaitTime(_ times: [TimeInterval]) -> TimeInterval {
        guard !times.isEmpty else { return 0 }
        return times.reduce(0, +) / Double(times.count)
    }
    
    /// Helper function to create a LockMetric from repository metrics
    private func createLockMetric(from repoMetrics: RepositoryMetrics) -> LockMetric {
        let averageWaitTime = calculateAverageWaitTime(repoMetrics.acquisitionTimes)
        let maxWaitTime = repoMetrics.acquisitionTimes.max() ?? 0
        
        return LockMetric(
            attempts: repoMetrics.totalAttempts,
            successes: repoMetrics.successfulAcquisitions,
            failures: repoMetrics.failedAcquisitions,
            averageWaitTime: averageWaitTime,
            maxWaitTime: maxWaitTime
        )
    }
    
    /// Retrieves metrics for a specific lock
    /// - Parameter lockId: Identifier for the lock
    /// - Returns: Lock metrics if available
    public func getLockMetrics(for lockId: String) -> LockMetric? {
        guard let repoMetrics = metrics[lockId] else { return nil }
        return createLockMetric(from: repoMetrics)
    }
    
    /// Retrieves all lock metrics
    /// - Returns: Dictionary of lock IDs to their metrics
    public func getAllLockMetrics() -> [String: LockMetric] {
        var lockMetrics = [String: LockMetric]()
        
        for (lockId, repoMetrics) in metrics {
            lockMetrics[lockId] = createLockMetric(from: repoMetrics)
        }
        
        return lockMetrics
    }
    
    /// Clears all recorded metrics
    public func clearMetrics() {
        queue.async {
            metrics.removeAll()
            logger.log("All lock metrics cleared", level: .debug)
        }
    }
}

/// Represents a single lock metric entry
public struct LockMetric {
    /// The total number of lock attempts
    public let attempts: Int
    /// The number of successful lock acquisitions
    public let successes: Int
    /// The number of failed lock attempts
    public let failures: Int
    /// Average time spent waiting for lock (in seconds)
    public let averageWaitTime: TimeInterval
    /// Maximum time spent waiting for lock (in seconds)
    public let maxWaitTime: TimeInterval
    
    /// Creates a new lock metric entry
    /// - Parameters:
    ///   - attempts: Total number of lock attempts
    ///   - successes: Number of successful lock acquisitions
    ///   - failures: Number of failed lock attempts
    ///   - averageWaitTime: Average time spent waiting for lock
    ///   - maxWaitTime: Maximum time spent waiting for lock
    public init(
        attempts: Int,
        successes: Int,
        failures: Int,
        averageWaitTime: TimeInterval,
        maxWaitTime: TimeInterval
    ) {
        self.attempts = attempts
        self.successes = successes
        self.failures = failures
        self.averageWaitTime = averageWaitTime
        self.maxWaitTime = maxWaitTime
    }
}
