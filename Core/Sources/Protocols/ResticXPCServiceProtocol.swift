//
//  ResticXPCServiceProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Protocol for XPC service that executes Restic commands
@objc public protocol ResticXPCServiceProtocol: HealthCheckable {
    /// Ping the service to check availability
    /// - Returns: true if service is available
    @objc func ping() async -> Bool
    
    /// Initialize a new repository
    /// - Parameters:
    ///   - url: Repository URL
    ///   - username: Repository username
    ///   - password: Repository password
    /// - Throws: ResticError if initialization fails
    @objc func initializeRepository(at url: URL, username: String, password: String) async throws
    
    /// Create a backup
    /// - Parameters:
    ///   - source: Source path
    ///   - destination: Destination path
    ///   - username: Repository username
    ///   - password: Repository password
    /// - Throws: ResticError if backup fails
    @objc func backup(from source: URL, to destination: URL, username: String, password: String) async throws
    
    /// List snapshots in repository
    /// - Parameters:
    ///   - username: Repository username
    ///   - password: Repository password
    /// - Returns: List of snapshot IDs
    /// - Throws: ResticError if listing fails
    @objc func listSnapshots(username: String, password: String) async throws -> [String]
    
    /// Restore from backup
    /// - Parameters:
    ///   - source: Source path
    ///   - destination: Destination path
    ///   - username: Repository username
    ///   - password: Repository password
    /// - Throws: ResticError if restore fails
    @objc func restore(from source: URL, to destination: URL, username: String, password: String) async throws
}
