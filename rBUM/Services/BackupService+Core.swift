import Core
import Foundation

/// Extension providing core backup operations for BackupService
public extension BackupService {
    // MARK: - Core Operations

    /// Initializes a new repository.
    ///
    /// - Parameter repository: The repository to initialize
    func initializeRepository(_ repository: Repository) async throws {
        try await measure("Initialize Repository") {
            try await resticService.initializeRepository(at: URL(fileURLWithPath: repository.path))
        }
    }

    /// Creates a new backup.
    ///
    /// - Parameters:
    ///   - repository: The target repository
    ///   - paths: Paths to backup
    ///   - tags: Optional tags to apply to the backup
    func createBackup(
        to repository: Repository,
        paths: [String],
        tags: [String]?
    ) async throws {
        let id = UUID()
        let source = BackupSource(paths: paths)

        try await withBackupOperation(id: id, source: source) {
            // Convert paths to URLs
            let urls = paths.map { URL(fileURLWithPath: $0) }

            // Scan source directories
            var files: [URL] = []
            for url in urls {
                try await files.append(contentsOf: scanSourceDirectory(url))
            }

            // Create backup
            try await resticService.backup(
                files: files,
                to: URL(fileURLWithPath: repository.path),
                tags: tags
            )
        }
    }

    /// Lists snapshots in a repository.
    ///
    /// - Parameter repository: The repository to list snapshots from
    /// - Returns: Array of snapshots
    func listSnapshots(in repository: Repository) async throws -> [Snapshot] {
        try await measure("List Snapshots") {
            let snapshots = try await resticService.listSnapshots(
                in: URL(fileURLWithPath: repository.path)
            )
            return snapshots.map { Snapshot(from: $0) }
        }
    }

    /// Restores files from a snapshot.
    ///
    /// - Parameters:
    ///   - snapshot: The snapshot to restore from
    ///   - repository: The repository containing the snapshot
    ///   - destination: The destination path for restored files
    func restore(
        snapshot: Snapshot,
        from repository: Repository,
        to destination: String
    ) async throws {
        try await measure("Restore Snapshot") {
            try await resticService.restore(
                snapshot: snapshot.id,
                from: URL(fileURLWithPath: repository.path),
                to: URL(fileURLWithPath: destination)
            )
        }
    }
}
