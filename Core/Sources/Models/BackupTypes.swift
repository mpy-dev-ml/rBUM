import Foundation

/// Represents filter criteria for snapshot operations in a backup repository.
/// Used to filter snapshots based on hostname and tags when listing or managing snapshots.
public struct SnapshotFilter {
    /// Optional hostname to filter snapshots by. If provided, only snapshots from this host will be included.
    public let hostname: String?

    /// Optional array of tags to filter snapshots by. If provided, only snapshots containing all specified tags will be
    /// included.
    public let tags: [String]?

    /// Initialises a new SnapshotFilter with optional hostname and tags criteria.
    /// - Parameters:
    ///   - hostname: Optional hostname to filter by. If nil, snapshots from all hosts are included.
    ///   - tags: Optional array of tags to filter by. If nil, tag filtering is not applied.
    public init(hostname: String? = nil, tags: [String]? = nil) {
        self.hostname = hostname
        self.tags = tags
    }
}

/// Represents the current progress of a backup operation.
/// Provides detailed information about files processed, processing speed, and estimated completion time.
public struct BackupProgress {
    /// Total number of files that need to be processed in this backup operation
    public let totalFiles: Int

    /// Number of files that have been processed so far
    public let processedFiles: Int

    /// Current processing speed in bytes per second
    public let speed: Int64

    /// Total number of bytes processed so far
    public let processedBytes: Int64

    /// Estimated time remaining for the backup operation in seconds, if available
    public let estimatedTimeRemaining: TimeInterval?

    /// Initialises a new BackupProgress instance with the current backup operation status.
    /// - Parameters:
    ///   - totalFiles: Total number of files to process
    ///   - processedFiles: Number of files processed so far
    ///   - speed: Current processing speed in bytes per second
    ///   - processedBytes: Total bytes processed so far
    ///   - estimatedTimeRemaining: Estimated time remaining in seconds, if available
    public init(
        totalFiles: Int,
        processedFiles: Int,
        speed: Int64,
        processedBytes: Int64,
        estimatedTimeRemaining: TimeInterval?
    ) {
        self.totalFiles = totalFiles
        self.processedFiles = processedFiles
        self.speed = speed
        self.processedBytes = processedBytes
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}
