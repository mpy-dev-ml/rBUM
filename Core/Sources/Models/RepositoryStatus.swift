/// Repository statistics
struct RepositoryStats: Codable, Equatable {
    /// Total size of the repository in bytes
    let totalSize: UInt64

    /// Number of pack files
    let packFiles: UInt

    /// Number of snapshots
    let snapshots: UInt

    private enum CodingKeys: String, CodingKey {
        case totalSize = "total_size"
        case packFiles = "pack_files"
        case snapshots
    }
}

/// Represents the current operational status of a repository
public enum RepositoryStatusType {
    /// Repository is ready for operations
    case ready

    /// Repository has encountered an error
    /// - Parameter error: The error that occurred
    case error(Error)

    /// Repository is currently performing an operation
    /// - Parameter operation: Description of the current operation
    case inProgress(operation: String)

    /// Repository is locked, preventing concurrent operations
    case locked

    /// Repository is currently unavailable
    case unavailable
}

/// Model representing the status of a repository after a check operation
struct RepositoryStatus: Codable, Equatable {
    /// Whether the repository is valid
    let isValid: Bool

    /// Whether all pack files are complete and valid
    let packsValid: Bool

    /// Whether all index files are complete and valid
    let indexValid: Bool

    /// Whether all snapshots are complete and valid
    let snapshotsValid: Bool

    /// Any errors encountered during the check
    let errors: [String]

    /// Statistics about the repository
    let stats: RepositoryStats

    public let status: RepositoryStatusType
    public let lastCheck: Date?
    public let errorDetails: String?

    public init(
        status: RepositoryStatusType,
        lastCheck: Date? = nil,
        errorDetails: String? = nil
    ) {
        self.status = status
        self.lastCheck = lastCheck
        self.errorDetails = errorDetails
    }

    private enum CodingKeys: String, CodingKey {
        case isValid = "is_valid"
        case packsValid = "packs_valid"
        case indexValid = "index_valid"
        case snapshotsValid = "snapshots_valid"
        case errors
        case stats
    }
}
