//
//  RestoreServiceProtocol.swift
//  rBUM
//
//  Created by Matthew Yeager on 05/02/2025.
//


//
//  RestoreServiceProtocol.swift
//  Core
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Foundation

/// Protocol for managing restore operations from backups
public protocol RestoreServiceProtocol {
    /// Restore files from a snapshot
    /// - Parameters:
    ///   - snapshot: The snapshot to restore from
    ///   - repository: The repository containing the snapshot
    ///   - paths: Specific paths to restore (empty means restore all)
    ///   - target: Target directory for restored files
    /// - Throws: RestoreError if restore fails
    func restore(snapshot: ResticSnapshot, from repository: Repository, paths: [String], to target: String) async throws
    
    /// List available snapshots in a repository
    /// - Parameter repository: Repository to list snapshots from
    /// - Returns: Array of available snapshots
    /// - Throws: RestoreError if listing fails
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot]
}

/// Error types for restore operations
public enum RestoreError: LocalizedError {
    case invalidSnapshot
    case invalidPath(String)
    case restoreFailed(String)
    case snapshotListFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidSnapshot:
            return "Invalid snapshot"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .restoreFailed(let reason):
            return "Restore failed: \(reason)"
        case .snapshotListFailed(let reason):
            return "Failed to list snapshots: \(reason)"
        }
    }
}