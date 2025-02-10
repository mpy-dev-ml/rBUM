import Foundation

/// Protocol defining repository locking operations to handle concurrent access
public protocol RepositoryLockProtocol {
    /// Attempts to acquire a lock for the specified repository
    /// - Parameters:
    ///   - repository: The repository to lock
    ///   - operation: The operation requiring the lock
    ///   - timeout: Maximum time to wait for lock acquisition (default: 30 seconds)
    /// - Returns: A boolean indicating whether the lock was acquired
    /// - Throws: LockError if lock acquisition fails
    func acquireLock(
        for repository: Repository,
        operation: RepositoryOperation,
        timeout: TimeInterval
    ) async throws -> Bool

    /// Releases the lock for the specified repository
    /// - Parameters:
    ///   - repository: The repository to unlock
    ///   - operation: The operation that held the lock
    /// - Throws: LockError if lock release fails
    func releaseLock(
        for repository: Repository,
        operation: RepositoryOperation
    ) async throws

    /// Checks if a repository is currently locked
    /// - Parameter repository: The repository to check
    /// - Returns: Lock information if locked, nil otherwise
    /// - Throws: LockError if lock status check fails
    func checkLockStatus(for repository: Repository) async throws -> LockInfo?

    /// Breaks a stale lock for the specified repository
    /// - Parameter repository: The repository with the stale lock
    /// - Throws: LockError if breaking the lock fails
    func breakStaleLock(for repository: Repository) async throws
}

/// Represents different repository operations that require locking
public enum RepositoryOperation: String {
    case backup
    case restore
    case prune
    case check
    case init = "init"
    case maintenance = "maintenance"
}

/// Information about a repository lock
public struct LockInfo: Codable, Equatable {
    /// The operation that holds the lock
    public let operation: RepositoryOperation

    /// Timestamp when the lock was acquired
    public let timestamp: Date

    /// Process ID that holds the lock
    public let pid: Int

    /// Hostname of the machine holding the lock
    public let hostname: String

    /// Username that holds the lock
    public let username: String

    public init(
        operation: RepositoryOperation,
        timestamp: Date,
        pid: Int,
        hostname: String,
        username: String
    ) {
        self.operation = operation
        self.timestamp = timestamp
        self.pid = pid
        self.hostname = hostname
        self.username = username
    }
}

/// Errors that can occur during lock operations
public enum LockError: Error {
    /// Repository is already locked
    case alreadyLocked(LockInfo)

    /// Lock acquisition timed out
    case timeout(TimeInterval)

    /// Lock file is corrupted
    case corruptLockFile

    /// No permission to create/modify lock file
    case permissionDenied

    /// Lock operation failed
    case operationFailed(String)
}
