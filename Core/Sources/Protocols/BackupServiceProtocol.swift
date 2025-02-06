//
//  BackupServiceProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation

/// Protocol for backup operations
public protocol BackupServiceProtocol {
    /// Initialize a new repository
    /// - Parameter repository: Repository to initialize
    /// - Throws: Error if initialization fails
    func initializeRepository(_ repository: Repository) async throws
    
    /// Create a new backup snapshot
    /// - Parameters:
    ///   - repository: Repository to backup to
    ///   - paths: Paths to backup
    ///   - tags: Optional tags for the backup
    /// - Throws: Error if backup fails
    func createBackup(to repository: Repository, paths: [String], tags: [String]?) async throws
    
    /// List snapshots in a repository
    /// - Parameter repository: Repository to list snapshots from
    /// - Returns: Array of snapshots
    /// - Throws: Error if listing fails
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot]
    
    /// Restore files from a snapshot
    /// - Parameters:
    ///   - snapshot: Snapshot to restore from
    ///   - repository: Repository containing the snapshot
    ///   - paths: Paths to restore
    ///   - target: Target directory for restoration
    /// - Throws: Error if restoration fails
    func restore(snapshot: ResticSnapshot, from repository: Repository, paths: [String], to target: String) async throws
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
