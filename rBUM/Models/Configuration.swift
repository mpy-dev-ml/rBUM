//
//  Configuration.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Represents application-wide configuration settings
struct Configuration: Codable, Equatable {
    /// Default backup schedule interval in minutes (0 = manual only)
    var defaultBackupInterval: Int

    /// Maximum number of concurrent backup operations
    var maxConcurrentBackups: Int

    /// Whether to show notifications for backup operations
    var showBackupNotifications: Bool

    /// Whether to automatically check for repository health
    var autoCheckRepositoryHealth: Bool

    /// Interval in days for repository health checks (0 = manual only)
    var repositoryHealthCheckInterval: Int

    /// Whether to automatically clean up old snapshots
    var autoCleanupSnapshots: Bool

    /// Keep snapshots for at least this many days
    var keepSnapshotsForDays: Int

    /// Default compression level (0-9, 0 = no compression)
    var defaultCompressionLevel: Int

    /// Whether to exclude system cache directories by default
    var excludeSystemCaches: Bool

    /// Custom paths to exclude from backups by default
    var defaultExcludePaths: [String]

    /// Create configuration with default values
    static var `default`: Configuration {
        Configuration(
            defaultBackupInterval: 0, // Manual backups by default
            maxConcurrentBackups: 1, // One backup at a time
            showBackupNotifications: true, // Show notifications
            autoCheckRepositoryHealth: true, // Auto check health
            repositoryHealthCheckInterval: 7, // Weekly health checks
            autoCleanupSnapshots: false, // Manual cleanup by default
            keepSnapshotsForDays: 30, // Keep snapshots for 30 days
            defaultCompressionLevel: 6, // Default compression
            excludeSystemCaches: true, // Exclude caches
            defaultExcludePaths: [ // Common exclude paths
                "~/Library/Caches",
                "~/Library/Logs",
                "**/node_modules",
                "**/.git",
            ]
        )
    }
}
