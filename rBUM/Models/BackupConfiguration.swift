import Foundation
import Core

/// Represents a backup configuration
internal struct BackupConfiguration: Codable, Equatable, Identifiable {
    /// Unique identifier for the configuration
    internal let id: UUID
    
    /// Name of the backup configuration
    internal let name: String
    
    /// Optional description of what this backup does
    internal let description: String?
    
    /// Whether this backup configuration is enabled
    internal let enabled: Bool
    
    /// Schedule for running the backup
    internal let schedule: BackupSchedule?
    
    /// Source locations to backup
    internal let sources: [BackupSource]
    
    /// Paths to exclude from backup
    internal let excludedPaths: [String]
    
    /// Tags for organizing backups
    internal let tags: [BackupTag]
    
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
    internal init(
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
