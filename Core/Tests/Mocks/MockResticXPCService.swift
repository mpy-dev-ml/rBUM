//
//  MockResticXPCService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 05/02/2025.
//


//
//  MockResticXPCService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Foundation

/// A mock XPC service used for testing and initialization to break circular dependencies
public final class MockResticXPCService: NSObject, ResticXPCServiceProtocol, HealthCheckable {
    @objc public func ping() async -> Bool {
        return true
    }
    
    @objc public func initializeRepository(at url: URL, username: String, password: String) async throws {
        // No-op for mock
    }
    
    @objc public func backup(from source: URL, to destination: URL, username: String, password: String) async throws {
        // No-op for mock
    }
    
    @objc public func listSnapshots(username: String, password: String) async throws -> [String] {
        return []
    }
    
    @objc public func restore(from source: URL, to destination: URL, username: String, password: String) async throws {
        // No-op for mock
    }
    
    @objc public func executeCommand(_ command: String,
                             arguments: [String],
                             environment: [String: String],
                             workingDirectory: String,
                             bookmarks: [String: NSData]?,
                             retryCount: Int) async throws -> ProcessResult {
        throw ProcessError.executionFailed("Mock: Command execution not implemented")
    }
    
    @objc public private(set) var isHealthy: Bool = true
    
    @objc public func updateHealthStatus() async {
        do {
            isHealthy = try await performHealthCheck()
        } catch {
            isHealthy = false
        }
    }
    
    @objc public func performHealthCheck() async throws -> Bool {
        return true
    }
    
    // MARK: - HealthCheckable Implementation
}
