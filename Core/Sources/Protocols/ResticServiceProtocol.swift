import Foundation

/// Protocol for Restic backup operations
@objc public protocol ResticServiceProtocol: HealthCheckable {
    /// Initialize a new repository
    /// - Parameter url: Repository URL
    /// - Throws: ResticError if initialization fails
    @objc func initializeRepository(
        at url: URL
    ) async throws

    /// Create a backup
    /// - Parameters:
    ///   - source: Source path
    ///   - destination: Destination path
    /// - Throws: ResticError if backup fails
    @objc func backup(
        from source: URL,
        to destination: URL
    ) async throws

    /// List snapshots in repository
    /// - Returns: List of snapshot IDs
    /// - Throws: ResticError if listing fails
    @objc func listSnapshots() async throws -> [String]

    /// Restore from backup
    /// - Parameters:
    ///   - source: Source path
    ///   - destination: Destination path
    /// - Throws: ResticError if restore fails
    @objc func restore(
        from source: URL,
        to destination: URL
    ) async throws
}

/// File information returned by restic
public struct ResticFile {
    /// Full path to the file in the backup
    public let path: String

    /// Size of the file in bytes
    public let size: UInt64

    /// Last modification time of the file
    public let modTime: Date

    /// Hash of the file content
    public let hash: String

    /// Initialise a new ResticFile instance
    /// - Parameters:
    ///   - path: Full path to the file in the backup
    ///   - size: Size of the file in bytes
    ///   - modTime: Last modification time of the file
    ///   - hash: Hash of the file content
    public init(path: String, size: UInt64, modTime: Date, hash: String) {
        self.path = path
        self.size = size
        self.modTime = modTime
        self.hash = hash
    }
}

extension ResticServiceProtocol {
    /// Find files matching a pattern in a snapshot
    /// - Parameters:
    ///   - pattern: Search pattern (supports glob patterns)
    ///   - snapshot: Snapshot to search in
    ///   - repository: Repository containing the snapshot
    /// - Returns: Array of matching files
    /// - Throws: ResticError if operation fails
    func findFiles(
        matching pattern: String,
        in snapshot: ResticSnapshot,
        repository: Repository
    ) async throws -> [ResticFile]

    /// Find a specific file in a snapshot
    /// - Parameters:
    ///   - path: Full path of the file
    ///   - snapshot: Snapshot to search in
    ///   - repository: Repository containing the snapshot
    /// - Returns: File information if found, nil otherwise
    /// - Throws: ResticError if operation fails
    func findFile(
        path: String,
        in snapshot: ResticSnapshot,
        repository: Repository
    ) async throws -> ResticFile?
}
