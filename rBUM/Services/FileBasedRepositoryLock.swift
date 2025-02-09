import Core
import Foundation

/// File-based implementation of repository locking for macOS
final class FileBasedRepositoryLock: RepositoryLockProtocol {
    private let fileManager: FileManager
    private let processInfo: ProcessInfo
    private let logger: LoggerProtocol
    private let metricsTracker: LockMetricsTracker
    private var activeLocks: [String: Date] = [:] // Track lock acquisition times
    
    init(
        fileManager: FileManager = .default,
        processInfo: ProcessInfo = .processInfo,
        logger: LoggerProtocol,
        metricsTracker: LockMetricsTracker = LockMetricsTracker()
    ) {
        self.fileManager = fileManager
        self.processInfo = processInfo
        self.logger = logger
        self.metricsTracker = metricsTracker
    }
    
    private func handleLockTimeout(
        repository: Repository,
        operation: RepositoryOperation,
        timeout: TimeInterval
    ) throws {
        logger.error("Lock acquisition timed out after \(timeout) seconds")
        metricsTracker.recordFailedAcquisition(
            repository: repository,
            operation: operation,
            reason: LockError.timeout(timeout)
        )
        throw LockError.timeout(timeout)
    }
    
    private func handleExistingLock(
        repository: Repository,
        operation: RepositoryOperation,
        existingLock: LockInfo
    ) throws {
        logger.warning("Repository already locked by \(existingLock.operation.rawValue)")
        metricsTracker.recordFailedAcquisition(
            repository: repository,
            operation: operation,
            reason: LockError.alreadyLocked(existingLock)
        )
        throw LockError.alreadyLocked(existingLock)
    }
    
    private func createLockFile(
        repository: Repository,
        operation: RepositoryOperation,
        lockPath: String,
        startTime: Date
    ) throws -> Bool {
        let lockInfo = LockInfo(
            operation: operation,
            timestamp: Date(),
            pid: processInfo.processIdentifier,
            hostname: processInfo.hostName,
            username: NSUserName()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let lockData = try encoder.encode(lockInfo)
        
        try lockData.write(to: URL(fileURLWithPath: lockPath), options: .atomic)
        
        let acquisitionTime = Date().timeIntervalSince(startTime)
        activeLocks[repository.path] = Date()
        
        metricsTracker.recordAcquisition(
            repository: repository,
            operation: operation,
            acquisitionTime: acquisitionTime
        )
        
        logger.info("Lock acquired for \(operation.rawValue)")
        return true
    }
    
    public func acquireLock(
        for repository: Repository,
        operation: RepositoryOperation,
        timeout: TimeInterval = 30
    ) async throws -> Bool {
        let startTime = Date()
        let lockPath = getLockPath(for: repository)
        
        while true {
            let elapsedTime = Date().timeIntervalSince(startTime)
            
            if elapsedTime > timeout {
                try handleLockTimeout(repository: repository, operation: operation, timeout: timeout)
            }
            
            if let existingLock = try? await checkLockStatus(for: repository) {
                if isLockStale(existingLock) {
                    metricsTracker.recordStaleLock(repository: repository)
                    try await breakStaleLock(for: repository)
                    continue
                }
                
                try handleExistingLock(repository: repository, operation: operation, existingLock: existingLock)
            }
            
            do {
                return try createLockFile(
                    repository: repository,
                    operation: operation,
                    lockPath: lockPath,
                    startTime: startTime
                )
            } catch {
                if error is LockError { throw error }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                continue
            }
        }
    }
    
    public func releaseLock(
        for repository: Repository,
        operation: RepositoryOperation
    ) async throws {
        let lockPath = getLockPath(for: repository)
        
        guard let currentLock = try? await checkLockStatus(for: repository) else {
            logger.warning("No lock found to release")
            return
        }
        
        // Verify we own the lock
        guard currentLock.pid == processInfo.processIdentifier else {
            logger.error("Cannot release lock owned by another process")
            throw LockError.operationFailed("Lock owned by another process")
        }
        
        guard currentLock.operation == operation else {
            logger.error("Lock operation mismatch")
            throw LockError.operationFailed("Lock operation mismatch")
        }
        
        do {
            try fileManager.removeItem(atPath: lockPath)
            
            if let acquisitionTime = activeLocks[repository.path] {
                let holdTime = Date().timeIntervalSince(acquisitionTime)
                metricsTracker.recordRelease(
                    repository: repository,
                    operation: operation,
                    holdTime: holdTime
                )
                activeLocks.removeValue(forKey: repository.path)
            }
            
            logger.info("Lock released for \(operation.rawValue)")
        } catch {
            throw LockError.operationFailed("Failed to remove lock file: \(error.localizedDescription)")
        }
    }
    
    public func checkLockStatus(for repository: Repository) async throws -> LockInfo? {
        let lockPath = getLockPath(for: repository)
        
        guard fileManager.fileExists(atPath: lockPath) else {
            return nil
        }
        
        do {
            let lockData = try Data(contentsOf: URL(fileURLWithPath: lockPath))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(LockInfo.self, from: lockData)
        } catch {
            logger.error("Failed to read lock file: \(error.localizedDescription)")
            throw LockError.corruptLockFile
        }
    }
    
    public func breakStaleLock(for repository: Repository) async throws {
        let lockPath = getLockPath(for: repository)
        
        guard let lockInfo = try? await checkLockStatus(for: repository) else {
            logger.warning("No lock found to break")
            return
        }
        
        guard isLockStale(lockInfo) else {
            logger.error("Cannot break non-stale lock")
            throw LockError.operationFailed("Lock is not stale")
        }
        
        do {
            try fileManager.removeItem(atPath: lockPath)
            logger.info("Broke stale lock for \(lockInfo.operation.rawValue)")
        } catch {
            throw LockError.operationFailed("Failed to remove stale lock: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func getLockPath(for repository: Repository) -> String {
        return (repository.path as NSString).appendingPathComponent(".lock")
    }
    
    private func isLockStale(_ lockInfo: LockInfo) -> Bool {
        // Consider a lock stale if:
        // 1. Process no longer exists
        // 2. Lock is older than 1 hour
        let processExists = ProcessInfo.processInfo.processIdentifier != lockInfo.pid &&
            kill(pid_t(lockInfo.pid), 0) == 0
        
        let isOld = Date().timeIntervalSince(lockInfo.timestamp) > 3600
        
        return !processExists || isOld
    }
}
