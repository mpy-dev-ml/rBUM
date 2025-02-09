import Foundation

/// A discovered Restic repository in the filesystem
///
/// This type represents a Restic repository that has been found during a filesystem scan.
/// It contains all necessary information about the repository, including its location,
/// type, and associated metadata.
///
/// ## Overview
/// The `DiscoveredRepository` type is used throughout the repository discovery feature
/// to track and manage repositories that have been found. It implements `Identifiable`
/// and `Hashable` to support use in SwiftUI views and collections.
///
/// ## Example Usage
/// ```swift
/// let repository = DiscoveredRepository(
///     url: repositoryURL,
///     type: .local,
///     discoveredAt: Date(),
///     isVerified: false,
///     metadata: metadata
/// )
/// ```
///
/// ## Topics
/// ### Creating a Repository
/// - ``init(id:url:type:discoveredAt:isVerified:metadata:)``
///
/// ### Properties
/// - ``id``
/// - ``url``
/// - ``type``
/// - ``discoveredAt``
/// - ``isVerified``
/// - ``metadata``
public struct DiscoveredRepository: Identifiable, Hashable {
    /// Unique identifier for the repository
    public let id: UUID
    
    /// The URL where the repository was discovered
    public let url: URL
    
    /// The type of repository (local, SFTP, etc.)
    public let type: RepositoryType
    
    /// Timestamp when the repository was discovered
    public let discoveredAt: Date
    
    /// Whether the repository has been verified as a valid Restic repository
    public let isVerified: Bool
    
    /// Additional metadata found during discovery
    public let metadata: RepositoryMetadata
    
    /// Creates a new discovered repository instance
    /// - Parameters:
    ///   - id: Unique identifier for the repository
    ///   - url: The URL where the repository was discovered
    ///   - type: The type of repository
    ///   - discoveredAt: Timestamp of discovery
    ///   - isVerified: Whether the repository has been verified
    ///   - metadata: Additional repository metadata
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
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: DiscoveredRepository, rhs: DiscoveredRepository) -> Bool {
        lhs.id == rhs.id
    }
}

/// Additional metadata about a discovered repository
///
/// This type encapsulates optional metadata that may be available for a discovered
/// repository. All properties are optional as they might not be available or
/// calculable for all repositories.
///
/// ## Overview
/// The `RepositoryMetadata` type provides additional context about a repository,
/// including its size, last modification date, and number of snapshots. This
/// information is collected during the discovery process but may not always be
/// available or may be expensive to calculate.
///
/// ## Example Usage
/// ```swift
/// let metadata = RepositoryMetadata(
///     size: 1024 * 1024 * 1024, // 1GB
///     lastModified: Date(),
///     snapshotCount: 42
/// )
/// ```
///
/// ## Topics
/// ### Creating Metadata
/// - ``init(size:lastModified:snapshotCount:)``
///
/// ### Properties
/// - ``size``
/// - ``lastModified``
/// - ``snapshotCount``
public struct RepositoryMetadata: Hashable {
    /// Size of the repository in bytes (if available)
    public let size: UInt64?
    
    /// Last modified date of the repository (if available)
    public let lastModified: Date?
    
    /// Number of snapshots found (if available)
    public let snapshotCount: Int?
    
    /// Creates a new repository metadata instance
    /// - Parameters:
    ///   - size: Size of the repository in bytes
    ///   - lastModified: Last modified date
    ///   - snapshotCount: Number of snapshots
    public init(
        size: UInt64? = nil,
        lastModified: Date? = nil,
        snapshotCount: Int? = nil
    ) {
        self.size = size
        self.lastModified = lastModified
        self.snapshotCount = snapshotCount
    }
}
