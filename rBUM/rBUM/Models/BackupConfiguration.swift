import Foundation

/// Represents a backup configuration
public struct BackupConfiguration: Codable, Equatable, Identifiable {
    /// Unique identifier for the configuration
    public let id: UUID
    
    /// Name of the backup configuration
    public let name: String
    
    /// Optional description of what this backup does
    public let description: String?
    
    /// Whether this backup configuration is enabled
    public let enabled: Bool
    
    /// Schedule for running the backup
    public let schedule: BackupSchedule?
    
    /// Source locations to backup
    public let sources: [BackupSource]
    
    /// Paths to exclude from backup
    public let excludedPaths: [String]
    
    /// Tags for organizing backups
    public let tags: [BackupTag]
    
    /// Creates a new backup configuration
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - name: Name of the backup configuration
    ///   - description: Optional description
    ///   - enabled: Whether the backup is enabled
    ///   - schedule: Optional backup schedule
    ///   - sources: Source locations to backup
    ///   - excludedPaths: Paths to exclude
    ///   - tags: Tags for organization
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        enabled: Bool = true,
        schedule: BackupSchedule? = nil,
        sources: [BackupSource] = [],
        excludedPaths: [String] = [],
        tags: [BackupTag] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.enabled = enabled
        self.schedule = schedule
        self.sources = sources
        self.excludedPaths = excludedPaths
        self.tags = tags
    }
}
