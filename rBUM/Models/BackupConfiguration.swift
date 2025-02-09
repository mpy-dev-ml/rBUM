//
//  BackupConfiguration.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Core
import Foundation

/// Represents a backup configuration
struct BackupConfiguration: Codable, Equatable, Identifiable {
    /// Unique identifier for the configuration
    let id: UUID

    /// Name of the backup configuration
    let name: String

    /// Optional description of what this backup does
    let description: String?

    /// Whether this backup configuration is enabled
    let enabled: Bool

    /// Schedule for running the backup
    let schedule: BackupSchedule?

    /// Source locations to backup
    let sources: [URL]

    /// Whether to include hidden files in backup
    let includeHidden: Bool

    /// Whether to verify after backup completion
    let verifyAfterBackup: Bool

    /// Repository to use for backup
    let repository: Repository?

    /// Initialise a new backup configuration
    /// - Parameters:
    ///   - id: Unique identifier for the configuration
    ///   - name: Name of the backup configuration
    ///   - description: Optional description of what this backup does
    ///   - enabled: Whether this backup configuration is enabled
    ///   - schedule: Schedule for running the backup
    ///   - sources: Source locations to backup
    ///   - includeHidden: Whether to include hidden files in backup
    ///   - verifyAfterBackup: Whether to verify after backup completion
    ///   - repository: Repository to use for backup
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        enabled: Bool = true,
        schedule: BackupSchedule? = nil,
        sources: [URL] = [],
        includeHidden: Bool = false,
        verifyAfterBackup: Bool = true,
        repository: Repository? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.enabled = enabled
        self.schedule = schedule
        self.sources = sources
        self.includeHidden = includeHidden
        self.verifyAfterBackup = verifyAfterBackup
        self.repository = repository
    }
}
