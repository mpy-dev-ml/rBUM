//
//  ResticServiceProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Protocol for Restic backup operations
public protocol ResticServiceProtocol: HealthCheckable {
    /// Initialize a new repository
    /// - Parameter url: Repository URL
    /// - Throws: ResticError if initialization fails
    func initializeRepository(
        at url: URL
    ) async throws

    /// Create a backup
    /// - Parameters:
    ///   - source: Source path
    ///   - destination: Destination path
    /// - Throws: ResticError if backup fails
    func backup(
        from source: URL,
        to destination: URL
    ) async throws

    /// List snapshots in repository
    /// - Returns: List of snapshot IDs
    /// - Throws: ResticError if listing fails
    func listSnapshots() async throws -> [String]

    /// Restore from backup
    /// - Parameters:
    ///   - source: Source path
    ///   - destination: Destination path
    /// - Throws: ResticError if restore fails
    func restore(
        from source: URL,
        to destination: URL
    ) async throws
}
