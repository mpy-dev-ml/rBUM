//
//  MockResticXPCService.swift
//  rBUM
//
//  Created by Matthew Yeager on 05/02/2025.
//


//
//  MockResticXPCService.swift
//  CoreTests
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Foundation

/// A mock XPC service used for testing and initialization to break circular dependencies
public final class MockResticXPCService: NSObject, ResticXPCServiceProtocol {
    public func ping() async -> Bool {
        return true
    }
    
    public func initializeRepository(at url: URL, username: String, password: String) async throws {
        // No-op for mock
    }
    
    public func backup(from source: URL, to destination: URL, username: String, password: String) async throws {
        // No-op for mock
    }
    
    public func listSnapshots(username: String, password: String) async throws -> [String] {
        return []
    }
    
    public func restore(from source: URL, to destination: URL, username: String, password: String) async throws {
        // No-op for mock
    }
    
    public func executeCommand(_ command: String,
                             arguments: [String],
                             environment: [String: String],
                             workingDirectory: String,
                             bookmarks: [String: NSData]?,
                             retryCount: Int) async throws -> ProcessResult {
        throw ProcessError.executionFailed("Mock: Command execution not implemented")
    }
    
    public var isHealthy: Bool {
        return true
    }
    
    public func performHealthCheck() async -> Bool {
        return true
    }
}
