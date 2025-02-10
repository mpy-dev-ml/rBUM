import Core
import Foundation

// MARK: - BackupServiceProtocol Implementation

public extension BackupService {
    /// Initialises a new backup repository.
    /// - Parameter repository: The repository to initialise
    /// - Throws: ResticError if the initialisation fails
    func initializeRepository(_ repository: Repository) async throws {
        try await resticService.initializeRepository(repository)
    }

    /// Creates a new backup of the specified paths in the target repository.
    /// - Parameters:
    ///   - repository: The repository to store the backup in
    ///   - paths: List of file paths to back up
    ///   - tags: Optional tags to associate with the backup
    /// - Throws: BackupError if the backup operation fails
    func createBackup(
        to repository: Repository,
        paths: [String],
        tags: [String]
    ) async throws {
        let id = UUID()
        await backupState.insert(id)
        defer { Task { await backupState.remove(id) } }

        // Record operation start
        let operation = BackupOperation(
            id: id,
            source: URL(fileURLWithPath: paths.first ?? ""),
            destination: repository.url,
            excludes: [],
            tags: tags,
            startTime: Date()
        )

        do {
            try await resticService.createBackup(
                repository: repository,
                paths: paths,
                tags: tags
            )
        } catch {
            throw BackupError.executionFailed(error)
        }
    }

    /// Lists all snapshots in the specified repository.
    /// - Parameter repository: The repository to list snapshots from
    /// - Returns: Array of ResticSnapshot objects
    /// - Throws: ResticError if the operation fails
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        try await resticService.listSnapshots(in: repository)
    }

    /// Restores a snapshot from a repository to a specified destination.
    /// - Parameters:
    ///   - snapshot: The snapshot to restore
    ///   - repository: The repository containing the snapshot
    ///   - destination: Local path where the snapshot should be restored
    /// - Throws: ResticError if the restore operation fails
    func restoreSnapshot(
        _ snapshot: ResticSnapshot,
        from repository: Repository,
        to destination: String
    ) async throws {
        try await resticService.restoreSnapshot(
            snapshot,
            from: repository,
            to: destination
        )
    }

    /// Deletes a snapshot from a repository.
    /// - Parameters:
    ///   - snapshot: The snapshot to delete
    ///   - repository: The repository containing the snapshot
    /// - Throws: ResticError if the delete operation fails
    func deleteSnapshot(
        _ snapshot: ResticSnapshot,
        from repository: Repository
    ) async throws {
        try await resticService.deleteSnapshot(
            snapshot,
            from: repository
        )
    }

    /// Verifies the integrity of a repository.
    /// - Parameter repository: The repository to verify
    /// - Throws: ResticError if the verification fails
    func verifyRepository(_ repository: Repository) async throws {
        try await resticService.verifyRepository(repository)
    }

    /// Prunes old snapshots from a repository to free up space.
    /// - Parameter repository: The repository to prune
    /// - Throws: ResticError if the prune operation fails
    func pruneRepository(_ repository: Repository) async throws {
        try await resticService.pruneRepository(repository)
    }
}
