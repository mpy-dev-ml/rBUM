import Foundation

/// Protocol defining backup service operations
protocol BackupServiceProtocol {
    /// Create a new backup
    /// - Parameters:
    ///   - paths: Paths to backup
    ///   - repository: Target repository
    ///   - credentials: Repository credentials
    ///   - tags: Optional tags to associate with the backup
    ///   - onProgress: Callback for backup progress updates
    ///   - onStatusChange: Callback for backup status changes
    func createBackup(
        paths: [URL],
        to repository: Repository,
        credentials: RepositoryCredentials,
        tags: [String]?,
        onProgress: ((BackupProgress) -> Void)?,
        onStatusChange: ((BackupStatus) -> Void)?
    ) async throws
}

/// Represents the progress of a backup operation
struct BackupProgress {
    let totalFiles: Int
    let processedFiles: Int
    let totalBytes: Int64
    let processedBytes: Int64
}

/// Represents the status of a backup operation
enum BackupStatus {
    case preparing
    case running
    case paused
    case completed
    case failed(Error)
}
