import Core
import Foundation

/// Service for handling task recovery and retries
final class MaintenanceTaskRecovery {
    private let logger: LoggerProtocol
    private let configStore: MaintenanceConfigurationStore
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    
    private var taskHistory: [String: [TaskAttempt]] = [:]
    private let queue = DispatchQueue(label: "com.rbum.taskrecovery")
    
    struct TaskAttempt: Codable {
        let task: MaintenanceTask
        let timestamp: Date
        let error: String
        let wasRecovered: Bool
    }
    
    init(
        logger: LoggerProtocol,
        configStore: MaintenanceConfigurationStore,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 300 // 5 minutes
    ) {
        self.logger = logger
        self.configStore = configStore
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }
    
    /// Records a task failure and determines if it should be retried
    func handleTaskFailure(
        task: MaintenanceTask,
        error: Error,
        repository: Repository
    ) -> Bool {
        queue.sync {
            let key = "\(repository.path):\(task.rawValue)"
            var attempts = taskHistory[key] ?? []
            
            // Add new attempt
            attempts.append(TaskAttempt(
                task: task,
                timestamp: Date(),
                error: error.localizedDescription,
                wasRecovered: false
            ))
            
            // Keep only recent attempts
            let recentAttempts = attempts.filter {
                Date().timeIntervalSince($0.timestamp) < 24 * 60 * 60 // Last 24 hours
            }
            
            taskHistory[key] = recentAttempts
            
            // Check if we should retry
            return shouldRetryTask(task, attempts: recentAttempts)
        }
    }
    
    /// Checks if a task should be retried based on its history
    private func shouldRetryTask(
        _ task: MaintenanceTask,
        attempts: [TaskAttempt]
    ) -> Bool {
        // Don't retry if we've exceeded max attempts
        if attempts.count >= maxRetries {
            logger.warning("Max retries exceeded for task: \(task.rawValue)")
            return false
        }
        
        // Check if enough time has passed since last attempt
        if let lastAttempt = attempts.last {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt.timestamp)
            if timeSinceLastAttempt < retryDelay {
                logger.info("Too soon to retry task: \(task.rawValue)")
                return false
            }
        }
        
        return true
    }
    
    /// Gets recovery strategy for a failed task
    func getRecoveryStrategy(
        for task: MaintenanceTask,
        error: Error
    ) -> RecoveryStrategy {
        // Determine strategy based on error and task type
        switch task {
        case .healthCheck:
            return .retryImmediately // Critical task, retry right away
            
        case .checkIntegrity:
            if error is LockError {
                return .retryWithDelay(delay: 60) // Wait for lock to be released
            }
            return .retryWithBackoff(initialDelay: 300, maxDelay: 3600)
            
        case .prune:
            if error is DiskSpaceError {
                return .skipUntilSpaceAvailable
            }
            return .retryWithBackoff(initialDelay: 600, maxDelay: 7200)
            
        case .rebuildIndex:
            if error is MemoryError {
                return .retryWhenResourcesAvailable
            }
            return .retryWithBackoff(initialDelay: 300, maxDelay: 3600)
            
        case .removeStaleSnapshots:
            return .retryWithBackoff(initialDelay: 900, maxDelay: 7200)
        }
    }
    
    /// Executes a task with retry logic
    func executeWithRetry(
        task: MaintenanceTask,
        repository: Repository,
        execution: @escaping () async throws -> Void
    ) async throws {
        var attempt = 0
        var delay = 0.0
        
        while attempt < maxRetries {
            do {
                if attempt > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                try await execution()
                return
            } catch {
                attempt += 1
                
                if !handleTaskFailure(task: task, error: error, repository: repository) {
                    throw error
                }
                
                let strategy = getRecoveryStrategy(for: task, error: error)
                switch strategy {
                case .retryImmediately:
                    delay = 0
                case .retryWithDelay(let newDelay):
                    delay = newDelay
                case .retryWithBackoff(let initialDelay, let maxDelay):
                    delay = min(initialDelay * pow(2.0, Double(attempt - 1)), maxDelay)
                case .retryWhenResourcesAvailable:
                    try await waitForResources()
                    delay = 0
                case .skipUntilSpaceAvailable:
                    try await waitForDiskSpace()
                    delay = 0
                }
                
                logger.info("Retrying task \(task.rawValue) after \(delay) seconds")
            }
        }
        
        throw MaintenanceError.maxRetriesExceeded
    }
    
    private func waitForResources() async throws {
        // Wait until system resources are available
        while true {
            let load = ProcessInfo.processInfo.systemUptime
            if load < 3.0 {
                return
            }
            try await Task.sleep(nanoseconds: 30 * 1_000_000_000) // Check every 30 seconds
        }
    }
    
    private func waitForDiskSpace() async throws {
        // Wait until sufficient disk space is available
        while true {
            let url = URL(fileURLWithPath: "/")
            do {
                let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
                if let capacity = values.volumeAvailableCapacity,
                   capacity > 1024 * 1024 * 1024 { // 1 GB
                    return
                }
            } catch {
                throw error
            }
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000) // Check every minute
        }
    }
}

/// Strategies for recovering from task failures
enum RecoveryStrategy {
    case retryImmediately
    case retryWithDelay(delay: TimeInterval)
    case retryWithBackoff(initialDelay: TimeInterval, maxDelay: TimeInterval)
    case retryWhenResourcesAvailable
    case skipUntilSpaceAvailable
}

/// Errors specific to disk space issues
enum DiskSpaceError: Error {
    case insufficientSpace(needed: Int64, available: Int64)
}

/// Errors specific to memory issues
enum MemoryError: Error {
    case insufficientMemory(needed: Int64, available: Int64)
}
