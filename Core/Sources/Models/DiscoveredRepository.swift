import Foundation

// MARK: - RepositoryType

/// Type of repository storage
///
/// This enum represents the different types of storage backends
/// that Restic supports for repositories.
///
/// Each type has specific:
/// - Connection requirements
/// - Authentication methods
/// - Performance characteristics
/// - Usage considerations
///
/// Example usage:
/// ```swift
/// // Create a local repository
/// let localRepo = DiscoveredRepository(
///     url: localURL,
///     type: .local,
///     discoveredAt: Date(),
///     isVerified: true,
///     metadata: metadata
/// )
///
/// // Create an S3 repository
/// let s3Repo = DiscoveredRepository(
///     url: s3URL,
///     type: .s3,
///     discoveredAt: Date(),
///     isVerified: false,
///     metadata: metadata
/// )
/// ```
public enum RepositoryType: String, Codable, CaseIterable {
    /// Local filesystem repository
    ///
    /// Used for repositories stored on:
    /// - Internal drives
    /// - External drives
    /// - Network shares
    case local

    /// SFTP-based remote repository
    ///
    /// Used for repositories stored on:
    /// - SSH servers
    /// - NAS devices
    /// - Remote Unix systems
    case sftp

    /// REST-based remote repository
    ///
    /// Used for repositories exposed via:
    /// - REST APIs
    /// - HTTP/HTTPS endpoints
    /// - Custom server implementations
    case rest

    /// S3-compatible storage repository
    ///
    /// Used with services like:
    /// - Amazon S3
    /// - MinIO
    /// - Wasabi
    /// - Backblaze B2
    case s3

    /// Azure Blob storage repository
    ///
    /// Used for repositories in:
    /// - Azure Blob Storage
    /// - Azure Storage Accounts
    case azure

    /// Google Cloud Storage repository
    ///
    /// Used for repositories in:
    /// - Google Cloud Storage buckets
    /// - Google Workspace environments
    case gcs

    /// Repository hosted on rclone
    ///
    /// Used with rclone to support:
    /// - Multiple cloud providers
    /// - Custom storage backends
    /// - Advanced configuration
    case rclone

    // MARK: Public

    /// User-friendly display name for the repository type
    ///
    /// This property provides localised, human-readable names
    /// suitable for display in user interfaces.
    public var displayName: String {
        switch self {
        case .local:
            "Local Storage"
        case .sftp:
            "SFTP Server"
        case .rest:
            "REST Server"
        case .s3:
            "S3 Storage"
        case .azure:
            "Azure Storage"
        case .gcs:
            "Google Cloud"
        case .rclone:
            "Rclone Storage"
        }
    }
}

// MARK: - DiscoveredRepository

/// A discovered Restic repository in the filesystem
///
/// This type represents a Restic repository that has been found during
/// a filesystem scan. It contains all necessary information about the
/// repository, including:
/// - Location (URL)
/// - Storage type
/// - Discovery timestamp
/// - Verification status
/// - Associated metadata
///
/// Example usage:
/// ```swift
/// // Create a new repository instance
/// let repository = DiscoveredRepository(
///     url: fileURL,
///     type: .local,
///     discoveredAt: Date(),
///     isVerified: true,
///     metadata: RepositoryMetadata(
///         size: 1024 * 1024 * 1024,
///         lastModified: Date(),
///         snapshotCount: 42
///     )
/// )
///
/// // Access repository properties
/// print(
///     """
///     Found \(repository.type.displayName) repository at \
///     \(repository.url.lastPathComponent)
///     """
/// )
///
/// // Check verification status
/// if repository.isVerified {
///     print(
///         """
///         Repository contains \(repository.metadata.snapshotCount ?? 0) \
///         snapshots
///         """
///     )
/// }
/// ```
public struct DiscoveredRepository: Identifiable, Hashable {
    // MARK: Lifecycle

    /// Creates a new discovered repository instance
    /// - Parameters:
    ///   - id: Unique identifier for the repository
    ///   - url: The URL where the repository was discovered
    ///   - type: The type of repository
    ///   - discoveredAt: Timestamp of discovery
    ///   - isVerified: Whether the repository has been verified
    ///   - metadata: Additional repository metadata
    ///
    /// Example:
    /// ```swift
    /// let repository = DiscoveredRepository(
    ///     id: UUID(),
    ///     url: fileURL,
    ///     type: .local,
    ///     discoveredAt: Date(),
    ///     isVerified: true,
    ///     metadata: RepositoryMetadata(
    ///         size: 1024 * 1024 * 1024,
    ///         lastModified: Date(),
    ///         snapshotCount: 42
    ///     )
    /// )
    /// ```
    public init(
        id: UUID = UUID(),
        url: URL,
        type: RepositoryType,
        discoveredAt: Date,
        isVerified: Bool,
        metadata: RepositoryMetadata
    ) {
        self.id = id
        self.url = url
        self.type = type
        self.discoveredAt = discoveredAt
        self.isVerified = isVerified
        self.metadata = metadata
    }

    // MARK: Public

    /// Unique identifier for the repository
    ///
    /// Used to:
    /// - Track repositories
    /// - Support SwiftUI integration
    /// - Enable stable identification
    public let id: UUID

    /// The URL where the repository was discovered
    ///
    /// Can be:
    /// - Local filesystem path
    /// - Remote storage URL
    /// - Custom URL scheme
    public let url: URL

    /// The type of repository (local, SFTP, etc.)
    ///
    /// Determines:
    /// - Access method
    /// - Authentication requirements
    /// - Performance characteristics
    public let type: RepositoryType

    /// Timestamp when the repository was discovered
    ///
    /// Used to:
    /// - Track discovery order
    /// - Implement caching
    /// - Support cleanup
    public let discoveredAt: Date

    /// Whether the repository has been verified
    ///
    /// Indicates if the repository:
    /// - Is accessible
    /// - Contains valid data
    /// - Can be opened
    public let isVerified: Bool

    /// Additional metadata found during discovery
    ///
    /// Contains optional information about:
    /// - Repository size
    /// - Modification time
    /// - Snapshot count
    public let metadata: RepositoryMetadata

    // MARK: - Equatable

    public static func == (
        lhs: DiscoveredRepository,
        rhs: DiscoveredRepository
    ) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - RepositoryMetadata

/// Additional metadata about a discovered repository
///
/// This type encapsulates optional metadata that may be available
/// for a discovered repository. All properties are optional as they
/// might not be available or calculable for all repositories.
///
/// The metadata includes:
/// - Repository size
/// - Last modification time
/// - Number of snapshots
///
/// Example usage:
/// ```swift
/// let metadata = RepositoryMetadata(
///     size: 1024 * 1024 * 1024, // 1GB
///     lastModified: Date(),
///     snapshotCount: 42
/// )
///
/// // Format size for display
/// let formatter = ByteCountFormatter()
/// print(
///     """
///     Repository size: \
///     \(formatter.string(fromByteCount: Int64(metadata.size ?? 0)))
///     """
/// )
///
/// // Check snapshot count
/// if let count = metadata.snapshotCount {
///     print("Contains \(count) snapshots")
/// }
/// ```
public struct RepositoryMetadata: Hashable {
    // MARK: Lifecycle

    /// Creates a new repository metadata instance
    /// - Parameters:
    ///   - size: Size of the repository in bytes
    ///   - lastModified: Last modified date
    ///   - snapshotCount: Number of snapshots
    ///
    /// Example:
    /// ```swift
    /// let metadata = RepositoryMetadata(
    ///     size: 2_147_483_648, // 2GB
    ///     lastModified: Date(),
    ///     snapshotCount: 100
    /// )
    /// ```
    public init(
        size: UInt64? = nil,
        lastModified: Date? = nil,
        snapshotCount: Int? = nil
    ) {
        self.size = size
        self.lastModified = lastModified
        self.snapshotCount = snapshotCount
    }

    // MARK: Public

    /// Size of the repository in bytes (if available)
    ///
    /// This may represent:
    /// - Total size on disk
    /// - Size before deduplication
    /// - Size excluding caches
    public let size: UInt64?

    /// Last modified date of the repository (if available)
    ///
    /// This may reflect:
    /// - Last backup time
    /// - Last prune operation
    /// - Last maintenance task
    public let lastModified: Date?

    /// Number of snapshots found (if available)
    ///
    /// This count includes:
    /// - All snapshot types
    /// - All backup sources
    /// - All time periods
    public let snapshotCount: Int?
}
