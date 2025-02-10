import Core
import Foundation

/// Service for managing backup operations.
///
/// BackupService provides a comprehensive solution for:
/// 1. Creating and managing backups
/// 2. Initialising and managing repositories
/// 3. Managing backup state and health
/// 4. Handling file operations safely
/// 5. Measuring and monitoring operations
///
/// Example usage:
/// ```swift
/// let backupService = BackupService(
///     resticService: resticService,
///     keychainService: keychainService,
///     repositoryLock: repositoryLock,
///     logger: logger
/// )
///
/// // Create a backup
/// try await backupService.createBackup(
///     to: repository,
///     paths: ["/path/to/backup"],
///     tags: ["important"]
/// )
///
/// // List snapshots
/// let snapshots = try await backupService.listSnapshots(in: repository)
/// ```
public final class BackupService: BaseSandboxedService, BackupServiceProtocol, HealthCheckable, Measurable,
    @unchecked Sendable
{
    // MARK: - Properties

    let resticService: ResticServiceProtocol
    private let repositoryLock: RepositoryLockProtocol
    private let maintenanceScheduler: MaintenanceSchedulerProtocol
    private let metricsTracker: LockMetricsTracker
    private let logger: LoggerProtocol

    // MARK: - Initialisation

    /// Initialises a new BackupService instance with required dependencies.
    /// - Parameters:
    ///   - resticService: Service for executing Restic commands
    ///   - repositoryLock: Service for managing repository locks
    ///   - maintenanceScheduler: Service for scheduling maintenance operations
    ///   - metricsTracker: Service for tracking lock metrics
    ///   - logger: Service for logging operations
    public init(
        resticService: ResticServiceProtocol,
        repositoryLock: RepositoryLockProtocol,
        maintenanceScheduler: MaintenanceSchedulerProtocol,
        metricsTracker: LockMetricsTracker,
        logger: LoggerProtocol
    ) {
        self.resticService = resticService
        self.repositoryLock = repositoryLock
        self.maintenanceScheduler = maintenanceScheduler
        self.metricsTracker = metricsTracker
        self.logger = logger
        super.init()
    }
}

// MARK: - Repository Operations

public extension BackupService {
    /// Initialises a new repository at the specified location.
    /// - Parameter repository: The repository to initialise
    /// - Throws: BackupError if initialisation fails or lock cannot be acquired
    func initializeRepository(_ repository: Repository) async throws {
        guard try await repositoryLock.acquireLock(
            for: repository,
            operation: .init,
            timeout: 30
        ) else {
            throw BackupError.lockAcquisitionFailed
        }

        defer {
            try? await repositoryLock.releaseLock(for: repository)
        }

        try await resticService.initRepository(repository)
    }

    /// Checks the integrity and accessibility of a repository.
    /// - Parameter repository: The repository to check
    /// - Returns: Boolean indicating if the repository is valid
    /// - Throws: BackupError if check fails or lock cannot be acquired
    func checkRepository(_ repository: Repository) async throws -> Bool {
        guard try await repositoryLock.acquireLock(
            for: repository,
            operation: .check,
            timeout: 30
        ) else {
            throw BackupError.lockAcquisitionFailed
        }

        defer {
            try? await repositoryLock.releaseLock(for: repository)
        }

        return try await resticService.checkRepository(repository)
    }
}

// MARK: - Backup Operations

public extension BackupService {
    /// Starts a new backup operation with the specified configuration.
    /// - Parameter configuration: Configuration for the backup operation
    /// - Throws: BackupError if backup fails or lock cannot be acquired
    func startBackup(configuration: BackupConfiguration) async throws {
        guard try await repositoryLock.acquireLock(
            for: configuration.repository,
            operation: .backup,
            timeout: 30
        ) else {
            throw BackupError.lockAcquisitionFailed
        }

        defer {
            try? await repositoryLock.releaseLock(for: configuration.repository)
        }

        try await resticService.startBackup(configuration)
    }

    /// Cancels the currently running backup operation.
    /// - Throws: BackupError if cancellation fails
    func cancelBackup() async throws {
        try await resticService.cancelBackup()
    }

    /// Retrieves the current progress of an ongoing backup operation.
    /// - Returns: Current backup progress information
    /// - Throws: BackupError if progress cannot be retrieved
    func getBackupProgress() async throws -> BackupProgress {
        try await resticService.getBackupProgress()
    }
}

// MARK: - Snapshot Management

public extension BackupService {
    /// Lists snapshots in the specified repository, optionally filtered by criteria.
    /// - Parameters:
    ///   - repository: The repository to list snapshots from
    ///   - filter: Optional filter criteria for the snapshots
    /// - Returns: Array of matching snapshots
    /// - Throws: BackupError if listing fails or lock cannot be acquired
    func listSnapshots(
        in repository: Repository,
        filter: SnapshotFilter? = nil
    ) async throws -> [ResticSnapshot] {
        guard try await repositoryLock.acquireLock(
            for: repository,
            operation: .list,
            timeout: 30
        ) else {
            throw BackupError.lockAcquisitionFailed
        }

        defer {
            try? await repositoryLock.releaseLock(for: repository)
        }

        return try await resticService.listSnapshots(in: repository, filter: filter)
    }

    /// Removes specified snapshots from a repository.
    /// - Parameters:
    ///   - snapshots: Array of snapshots to remove
    ///   - repository: The repository to remove snapshots from
    /// - Throws: BackupError if removal fails or lock cannot be acquired
    func removeSnapshots(
        _ snapshots: [ResticSnapshot],
        from repository: Repository
    ) async throws {
        guard try await repositoryLock.acquireLock(
            for: repository,
            operation: .prune,
            timeout: 30
        ) else {
            throw BackupError.lockAcquisitionFailed
        }

        defer {
            try? await repositoryLock.releaseLock(for: repository)
        }

        try await resticService.removeSnapshots(snapshots, from: repository)
    }
}

// MARK: - Maintenance & Metrics

public extension BackupService {
    /// Triggers maintenance operations on the specified repository.
    /// - Parameter repository: The repository to perform maintenance on
    /// - Returns: Result of the maintenance operation
    /// - Throws: BackupError if maintenance fails
    func triggerMaintenance(for repository: Repository) async throws -> MaintenanceResult {
        try await maintenanceScheduler.triggerMaintenance(for: repository)
    }

    /// Retrieves lock metrics for the specified repository.
    /// - Parameter repository: The repository to get metrics for
    /// - Returns: Lock metrics for the repository
    func getLockMetrics(for repository: Repository) -> LockMetrics {
        metricsTracker.getMetrics(for: repository)
    }
}

// MARK: - State Management

extension BackupService {
    private actor BackupState {
        var activeBackups: Set<UUID> = []
        var cachedHealthStatus: Bool = true

        func insert(_ id: UUID) {
            activeBackups.insert(id)
            updateCachedHealth()
        }

        func remove(_ id: UUID) {
            activeBackups.remove(id)
            updateCachedHealth()
        }

        var isEmpty: Bool {
            activeBackups.isEmpty
        }

        private func updateCachedHealth() {
            cachedHealthStatus = activeBackups.isEmpty
        }
    }

    private func updateHealthStatus() async {
        let isEmpty = await backupState.isEmpty
        let resticHealthy = await (try? resticService.performHealthCheck()) ?? false
        isHealthy = isEmpty && resticHealthy
    }
}
