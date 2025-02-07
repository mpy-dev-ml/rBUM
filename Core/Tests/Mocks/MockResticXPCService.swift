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
        true
    }

    /// Initialize a new Restic repository
    /// - Parameters:
    ///   - url: Repository location URL
    ///   - username: Repository username
    ///   - password: Repository password
    @objc public func initializeRepository(at _: URL, username _: String, password _: String) async throws {
        // No-op for mock
    }

    /// Backup data to a Restic repository
    /// - Parameters:
    ///   - source: Source data location
    ///   - destination: Backup destination
    ///   - username: Repository username
    ///   - password: Repository password
    @objc public func backup(from _: URL, to _: URL, username _: String, password _: String) async throws {
        // No-op for mock
    }

    /// List available snapshots in the repository
    /// - Parameters:
    ///   - username: Repository username
    ///   - password: Repository password
    /// - Returns: Empty array for mock implementation
    @objc public func listSnapshots(username _: String, password _: String) async throws -> [String] {
        []
    }

    /// Restore data from a Restic repository
    /// - Parameters:
    ///   - source: Source snapshot location
    ///   - destination: Restore destination
    ///   - username: Repository username
    ///   - password: Repository password
    @objc public func restore(from _: URL, to _: URL, username _: String, password _: String) async throws {
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
    @objc public func executeCommand(
        _: String,
        arguments _: [String],
        environment _: [String: String],
        workingDirectory _: String,
        bookmarks _: [String: NSData]?,
        retryCount _: Int
    ) async throws -> ProcessResult {
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
        true
    }
}
