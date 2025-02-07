//
//  MockResticXPCService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Foundation

/// A mock XPC service used for testing and initialization to break circular dependencies
public final class MockResticXPCService: NSObject, ResticXPCServiceProtocol, HealthCheckable {
    /// Ping the service to check availability
    /// - Returns: Always returns true for mock implementation
    @objc public func ping() async -> Bool {
        return true
    }
    
    /// Initialize a new Restic repository
    /// - Parameters:
    ///   - url: Repository location URL
    ///   - username: Repository username
    ///   - password: Repository password
    @objc public func initializeRepository(at url: URL, username: String, password: String) async throws {
        // No-op for mock
    }
    
    /// Backup data to a Restic repository
    /// - Parameters:
    ///   - source: Source data location
    ///   - destination: Backup destination
    ///   - username: Repository username
    ///   - password: Repository password
    @objc public func backup(from source: URL, to destination: URL, username: String, password: String) async throws {
        // No-op for mock
    }
    
    /// List available snapshots in the repository
    /// - Parameters:
    ///   - username: Repository username
    ///   - password: Repository password
    /// - Returns: Empty array for mock implementation
    @objc public func listSnapshots(username: String, password: String) async throws -> [String] {
        return []
    }
    
    /// Restore data from a Restic repository
    /// - Parameters:
    ///   - source: Source snapshot location
    ///   - destination: Restore destination
    ///   - username: Repository username
    ///   - password: Repository password
    @objc public func restore(from source: URL, to destination: URL, username: String, password: String) async throws {
        // No-op for mock
    }
    
    /// Execute a command through the XPC service
    /// - Parameters:
    ///   - command: Command to execute
    ///   - arguments: Command arguments
    ///   - environment: Environment variables
    ///   - workingDirectory: Working directory for command execution
    ///   - bookmarks: Security-scoped bookmarks
    ///   - retryCount: Number of retry attempts
    /// - Returns: Never returns, always throws for mock implementation
    /// - Throws: ProcessError.executionFailed
    @objc public func executeCommand(_ command: String,
                             arguments: [String],
                             environment: [String: String],
                             workingDirectory: String,
                             bookmarks: [String: NSData]?,
                             retryCount: Int) async throws -> ProcessResult {
        throw ProcessError.executionFailed("Mock: Command execution not implemented")
    }
    
    /// Current health state of the service
    @objc public private(set) var isHealthy: Bool = true
    
    /// Update the service health status
    @objc public func updateHealthStatus() async {
        do {
            isHealthy = try await performHealthCheck()
        } catch {
            isHealthy = false
        }
    }
    
    /// Perform a health check of the service
    /// - Returns: Always returns true for mock implementation
    @objc public func performHealthCheck() async throws -> Bool {
        return true
    }
}
