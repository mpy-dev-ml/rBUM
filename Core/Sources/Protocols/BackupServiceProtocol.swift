import Foundation
@_exported import Models

/// Protocol defining the core backup service functionality
public protocol BackupServiceProtocol {
    /// The delegate to receive backup operation updates
    var delegate: BackupServiceDelegate? { get set }

    // Core backup operations

    /// Starts a backup operation with the specified configuration
    /// - Parameter configuration: The configuration for the backup operation
    /// - Returns: A boolean indicating whether the backup was started successfully
    /// - Throws: BackupError if the operation cannot be started
    func startBackup(configuration: BackupConfiguration) throws -> Bool

    /// Cancels the currently running backup operation
    /// - Returns: A boolean indicating whether the backup was cancelled successfully
    /// - Throws: BackupError if the operation cannot be cancelled
    func cancelBackup() throws -> Bool

    /// Retrieves the current backup progress
    /// - Returns: The current backup progress information
    /// - Throws: BackupError if the progress cannot be retrieved
    func getBackupProgress() throws -> ResticProgress

    /// Checks if a backup operation is currently in progress
    /// - Returns: A boolean indicating whether a backup is running
    /// - Throws: BackupError if the status cannot be determined
    func isBackupInProgress() throws -> Bool

    // Configuration management

    /// Validates the backup configuration before starting
    /// - Parameter configuration: The configuration to validate
    /// - Throws: BackupError if the configuration is invalid
    func validateBackupConfiguration(_ configuration: BackupConfiguration) throws

    /// Retrieves the current backup configuration
    /// - Returns: The current backup configuration
    /// - Throws: BackupError if the configuration cannot be retrieved
    func getCurrentConfiguration() throws -> BackupConfiguration

    /// Updates the current backup configuration
    /// - Parameter configuration: The new configuration to set
    /// - Throws: BackupError if the configuration cannot be updated
    func updateConfiguration(_ configuration: BackupConfiguration) throws

    // Source management

    /// Retrieves the list of backup sources
    /// - Returns: An array of backup sources
    /// - Throws: BackupError if the sources cannot be retrieved
    func getBackupSources() throws -> [BackupSource]

    /// Adds a new backup source
    /// - Parameter source: The source to add
    /// - Throws: BackupError if the source cannot be added
    func addBackupSource(_ source: BackupSource) throws

    /// Removes a backup source
    /// - Parameter source: The source to remove
    /// - Throws: BackupError if the source cannot be removed
    func removeBackupSource(_ source: BackupSource) throws

    // Schedule management

    /// Retrieves the backup schedule for a given source
    /// - Parameter source: The source to get the schedule for
    /// - Returns: The backup schedule for the specified source
    /// - Throws: BackupError if the schedule cannot be retrieved
    func getBackupSchedule(for source: BackupSource) throws -> BackupSchedule

    /// Updates the backup schedule for a given source
    /// - Parameters:
    ///   - schedule: The new schedule to set
    ///   - source: The source to update the schedule for
    /// - Throws: BackupError if the schedule cannot be updated
    func updateBackupSchedule(_ schedule: BackupSchedule, for source: BackupSource) throws

    // Settings management

    /// Retrieves the backup settings for a given source
    /// - Parameter source: The source to get settings for
    /// - Returns: The backup settings for the specified source
    /// - Throws: BackupError if the settings cannot be retrieved
    func getBackupSettings(for source: BackupSource) throws -> BackupSettings

    /// Updates the backup settings for a given source
    /// - Parameters:
    ///   - settings: The new settings to set
    ///   - source: The source to update settings for
    /// - Throws: BackupError if the settings cannot be updated
    func updateBackupSettings(_ settings: BackupSettings, for source: BackupSource) throws

    // History and metrics

    /// Retrieves the list of completed backups
    /// - Returns: An array of completed backup configurations
    /// - Throws: BackupError if the list cannot be retrieved
    func getCompletedBackups() throws -> [BackupConfiguration]

    /// Retrieves the list of failed backups
    /// - Returns: An array of failed backup configurations
    /// - Throws: BackupError if the list cannot be retrieved
    func getFailedBackups() throws -> [BackupConfiguration]

    /// Clears the backup history
    /// - Returns: A boolean indicating whether the history was cleared successfully
    /// - Throws: BackupError if the history cannot be cleared
    func clearBackupHistory() throws -> Bool

    /// Retrieves the backup metrics for a given time period
    /// - Parameter period: The time period to get metrics for
    /// - Returns: The backup metrics for the specified period
    /// - Throws: BackupError if the metrics cannot be retrieved
    func getBackupMetrics(for period: TimePeriod) throws -> BackupMetrics

    /// Retrieves the backup history for a given time period
    /// - Parameter period: The time period to get history for
    /// - Returns: The backup history for the specified period
    /// - Throws: BackupError if the history cannot be retrieved
    func getBackupHistory(for period: TimePeriod) throws -> [BackupOperation]

    /// Retrieves the backup status for a given source
    /// - Parameter source: The source to get status for
    /// - Returns: The backup status for the specified source
    /// - Throws: BackupError if the status cannot be retrieved
    func getBackupStatus(for source: BackupSource) throws -> BackupStatus

    // Health check

    /// Performs a health check on the backup service
    /// - Returns: The health check result
    /// - Throws: BackupError if the health check fails
    func performHealthCheck() throws -> HealthCheckResult

    /// Performs a backup operation for the specified source
    /// - Parameters:
    ///   - source: The backup source to process
    ///   - options: Optional backup options to override repository defaults
    /// - Returns: The backup operation result
    /// - Throws: BackupError if the operation fails
    ///          LockError if unable to acquire repository lock
    func performBackup(
        for source: BackupSource,
        options: BackupOptions?
    ) async throws -> BackupResult

    /// Restores files from a backup snapshot
    /// - Parameters:
    ///   - snapshot: The snapshot to restore from
    ///   - destination: The destination path for restored files
    ///   - options: Optional restore options
    /// - Throws: RestoreError if the operation fails
    ///          LockError if unable to acquire repository lock
    func restore(
        from snapshot: ResticSnapshot,
        to destination: String,
        options: RestoreOptions?
    ) async throws

    /// Checks repository health and consistency
    /// - Parameter repository: The repository to check
    /// - Returns: Health check result
    /// - Throws: HealthCheckError if the operation fails
    ///          LockError if unable to acquire repository lock
    func checkHealth(for repository: Repository) async throws -> HealthCheckResult
}

/// Delegate protocol for receiving backup operation updates and status changes
public protocol BackupServiceDelegate: AnyObject {
    /// Called when a backup operation starts
    /// - Parameter backup: The backup configuration that started
    func backupDidStart(_ backup: BackupConfiguration)

    /// Called when a backup operation completes successfully
    /// - Parameter backup: The backup configuration that completed
    func backupDidComplete(_ backup: BackupConfiguration)

    /// Called when a backup operation fails
    /// - Parameters:
    ///   - backup: The backup configuration that failed
    ///   - error: The error that caused the failure
    func backupDidFail(_ backup: BackupConfiguration, with error: Error)

    /// Called when backup progress is updated
    /// - Parameter progress: The updated backup progress
    func backupProgressDidUpdate(_ progress: ResticProgress)
}

/// Options for repository initialization
public struct RepositoryOptions {
    /// Encryption algorithm to use
    public let encryption: EncryptionAlgorithm
    /// Additional repository configuration
    public let config: [String: Any]

    /// Initializes a new repository options instance
    /// - Parameters:
    ///   - encryption: The encryption algorithm to use (default: .aes256)
    ///   - config: Additional repository configuration (default: [:])
    public init(encryption: EncryptionAlgorithm = .aes256, config: [String: Any] = [:]) {
        self.encryption = encryption
        self.config = config
    }
}

/// Options for backup operations
public struct BackupOptions {
    /// Whether to create an incremental backup
    public let incremental: Bool
    /// Maximum upload speed in bytes per second
    public let uploadLimit: UInt64?
    /// Paths to exclude from backup
    public let excludePaths: [String]
    /// Whether to verify data after backup
    public let verify: Bool

    /// Initializes a new backup options instance
    /// - Parameters:
    ///   - incremental: Whether to create an incremental backup (default: true)
    ///   - uploadLimit: Maximum upload speed in bytes per second (default: nil)
    ///   - excludePaths: Paths to exclude from backup (default: [])
    ///   - verify: Whether to verify data after backup (default: true)
    public init(
        incremental: Bool = true,
        uploadLimit: UInt64? = nil,
        excludePaths: [String] = [],
        verify: Bool = true
    ) {
        self.incremental = incremental
        self.uploadLimit = uploadLimit
        self.excludePaths = excludePaths
        self.verify = verify
    }
}

/// Options for restore operations
public struct RestoreOptions {
    /// Whether to verify data during restore
    public let verify: Bool
    /// Whether to overwrite existing files
    public let overwrite: Bool
    /// Maximum download speed in bytes per second
    public let downloadLimit: UInt64?

    /// Initializes a new restore options instance
    /// - Parameters:
    ///   - verify: Whether to verify data during restore (default: true)
    ///   - overwrite: Whether to overwrite existing files (default: false)
    ///   - downloadLimit: Maximum download speed in bytes per second (default: nil)
    public init(
        verify: Bool = true,
        overwrite: Bool = false,
        downloadLimit: UInt64? = nil
    ) {
        self.verify = verify
        self.overwrite = overwrite
        self.downloadLimit = downloadLimit
    }
}

/// Options for repository check
public struct CheckOptions {
    /// Whether to read all data blobs
    public let readData: Bool
    /// Whether to check unused blobs
    public let checkUnused: Bool

    /// Initializes a new check options instance
    /// - Parameters:
    ///   - readData: Whether to read all data blobs (default: false)
    ///   - checkUnused: Whether to check unused blobs (default: true)
    public init(readData: Bool = false, checkUnused: Bool = true) {
        self.readData = readData
        self.checkUnused = checkUnused
    }
}

/// Retention policy for snapshot pruning
public struct RetentionPolicy {
    /// Keep last n snapshots
    public let keepLast: Int?
    /// Keep hourly snapshots for n hours
    public let keepHourly: Int?
    /// Keep daily snapshots for n days
    public let keepDaily: Int?
    /// Keep weekly snapshots for n weeks
    public let keepWeekly: Int?
    /// Keep monthly snapshots for n months
    public let keepMonthly: Int?
    /// Keep yearly snapshots for n years
    public let keepYearly: Int?
    /// Keep snapshots with these tags
    public let keepTags: [String]?

    /// Initializes a new retention policy instance
    /// - Parameters:
    ///   - keepLast: Keep last n snapshots (default: nil)
    ///   - keepHourly: Keep hourly snapshots for n hours (default: nil)
    ///   - keepDaily: Keep daily snapshots for n days (default: nil)
    ///   - keepWeekly: Keep weekly snapshots for n weeks (default: nil)
    ///   - keepMonthly: Keep monthly snapshots for n months (default: nil)
    ///   - keepYearly: Keep yearly snapshots for n years (default: nil)
    ///   - keepTags: Keep snapshots with these tags (default: nil)
    public init(
        keepLast: Int? = nil,
        keepHourly: Int? = nil,
        keepDaily: Int? = nil,
        keepWeekly: Int? = nil,
        keepMonthly: Int? = nil,
        keepYearly: Int? = nil,
        keepTags: [String]? = nil
    ) {
        self.keepLast = keepLast
        self.keepHourly = keepHourly
        self.keepDaily = keepDaily
        self.keepWeekly = keepWeekly
        self.keepMonthly = keepMonthly
        self.keepYearly = keepYearly
        self.keepTags = keepTags
    }
}

/// Result of repository check operation
public struct RepositoryCheckResult {
    /// Whether the check was successful
    public let success: Bool
    /// Total number of blobs checked
    public let blobsChecked: Int
    /// Size of checked data in bytes
    public let bytesChecked: UInt64
    /// Any errors encountered during check
    public let errors: [Error]

    /// Initializes a new repository check result instance
    /// - Parameters:
    ///   - success: Whether the check was successful
    ///   - blobsChecked: Total number of blobs checked
    ///   - bytesChecked: Size of checked data in bytes
    ///   - errors: Any errors encountered during check (default: [])
    public init(
        success: Bool,
        blobsChecked: Int,
        bytesChecked: UInt64,
        errors: [Error] = []
    ) {
        self.success = success
        self.blobsChecked = blobsChecked
        self.bytesChecked = bytesChecked
        self.errors = errors
    }
}

/// Result of pruning operation
public struct PruningResult {
    /// Number of snapshots removed
    public let snapshotsRemoved: Int
    /// Number of data blobs removed
    public let blobsRemoved: Int
    /// Size of reclaimed space in bytes
    public let bytesReclaimed: UInt64

    /// Initializes a new pruning result instance
    /// - Parameters:
    ///   - snapshotsRemoved: Number of snapshots removed
    ///   - blobsRemoved: Number of data blobs removed
    ///   - bytesReclaimed: Size of reclaimed space in bytes
    public init(
        snapshotsRemoved: Int,
        blobsRemoved: Int,
        bytesReclaimed: UInt64
    ) {
        self.snapshotsRemoved = snapshotsRemoved
        self.blobsRemoved = blobsRemoved
        self.bytesReclaimed = bytesReclaimed
    }
}

/// Represents the status of a backup operation
public enum BackupStatus: Equatable {
    /// Operation is preparing to start
    case preparing
    /// Operation is running
    case running
    /// Operation is paused
    case paused
    /// Operation completed successfully
    case completed
    /// Operation failed with error
    case failed(Error)

    /// Compares two backup status instances for equality
    /// - Parameters:
    ///   - lhs: The first backup status instance
    ///   - rhs: The second backup status instance
    /// - Returns: A boolean indicating whether the two instances are equal
    public static func == (lhs: BackupStatus, rhs: BackupStatus) -> Bool {
        switch (lhs, rhs) {
        case (.preparing, .preparing):
            true
        case (.running, .running):
            true
        case (.paused, .paused):
            true
        case (.completed, .completed):
            true
        case (.failed, .failed):
            true
        default:
            false
        }
    }
}

/// Supported encryption algorithms
public enum EncryptionAlgorithm: String {
    case aes256 = "AES-256"
    case chacha20 = "ChaCha20"
}
