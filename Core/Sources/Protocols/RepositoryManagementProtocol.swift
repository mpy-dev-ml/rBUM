import Foundation

/// Protocol defining repository management functionality
public protocol RepositoryManagementProtocol {
    /// Initialises a new repository with the given options.
    /// - Parameters:
    ///   - repository: The repository to initialise
    ///   - options: Optional configuration options for repository initialisation
    /// - Throws: BackupError if the operation fails
    func initializeRepository(_ repository: Repository, options: RepositoryOptions?) async throws

    /// Creates a new backup of the specified paths in the given repository.
    /// - Parameters:
    ///   - repository: The target repository for the backup
    ///   - paths: Array of file paths to backup
    ///   - tags: Optional array of tags to associate with the backup
    ///   - options: Optional backup configuration options
    /// - Returns: The created ResticSnapshot
    /// - Throws: BackupError if the operation fails
    func createBackup(
        to repository: Repository,
        paths: [String],
        tags: [String]?,
        options: BackupOptions?
    ) async throws -> ResticSnapshot

    /// Lists snapshots in the specified repository that match the given filter.
    /// - Parameters:
    ///   - repository: The repository to list snapshots from
    ///   - filter: Optional filter criteria for snapshots
    /// - Returns: Array of matching ResticSnapshots
    /// - Throws: BackupError if the operation fails
    func listSnapshots(
        in repository: Repository,
        filter: SnapshotFilter?
    ) async throws -> [ResticSnapshot]

    /// Restores files from a snapshot to the specified location.
    /// - Parameters:
    ///   - snapshot: The snapshot to restore from
    ///   - repository: The repository containing the snapshot
    ///   - paths: Optional specific paths to restore
    ///   - destination: The destination path for restored files
    ///   - options: Optional restore configuration options
    /// - Throws: BackupError if the operation fails
    func restore(
        snapshot: ResticSnapshot,
        from repository: Repository,
        paths: [String]?,
        to destination: String,
        options: RestoreOptions?
    ) async throws

    /// Checks the repository for consistency and errors.
    /// - Parameters:
    ///   - repository: The repository to check
    ///   - options: Optional check configuration options
    /// - Returns: The check results containing success status and any errors
    /// - Throws: BackupError if the operation fails
    func checkRepository(_ repository: Repository, options: CheckOptions?) async throws -> RepositoryCheckResult

    /// Prunes snapshots according to the specified retention policy.
    /// - Parameters:
    ///   - repository: The repository to prune
    ///   - policy: The retention policy defining which snapshots to keep
    /// - Returns: Results of the pruning operation
    /// - Throws: BackupError if the operation fails
    func pruneSnapshots(in repository: Repository, policy: RetentionPolicy) async throws -> PruningResult
    
    /// Retrieves the list of backup tags.
    ///
    /// - Returns: An array of backup tags
    /// - Throws: BackupError if the tags cannot be retrieved
    func getBackupTags() throws -> [BackupTag]
    
    /// Adds a new backup tag.
    ///
    /// - Parameter tag: The tag to add
    /// - Throws: BackupError if the tag cannot be added
    func addBackupTag(_ tag: BackupTag) throws
    
    /// Removes a backup tag.
    ///
    /// - Parameter tag: The tag to remove
    /// - Throws: BackupError if the tag cannot be removed
    func removeBackupTag(_ tag: BackupTag) throws
    
    /// Retrieves the backup queue state.
    ///
    /// - Returns: The current backup queue state
    /// - Throws: BackupError if the queue state cannot be retrieved
    func getBackupQueueState() throws -> BackupQueueState
    
    /// Updates the backup queue state.
    ///
    /// - Parameter state: The new queue state to set
    /// - Throws: BackupError if the queue state cannot be updated
    func updateBackupQueueState(_ state: BackupQueueState) throws
}
