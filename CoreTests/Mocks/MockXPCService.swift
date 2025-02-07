//
//  MockXPCService.swift
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
import XCTest

/// Mock XPC service for testing sandbox-compliant command execution
@objc final class MockXPCService: NSObject {
    var isConnected: Bool = false
    var lastCommand: String?
    var lastBookmark: Data?
    var shouldFailConnection: Bool = false
    var shouldFailExecution: Bool = false
    var accessedURLs: Set<URL> = []
    
    private(set) var commandHistory: [(command: String, bookmark: Data?)] = []
    private(set) var accessStartCount: Int = 0
    private(set) var accessStopCount: Int = 0
    
    // MARK: - HealthCheckable
    @objc public var isHealthy: Bool {
        isConnected && !shouldFailExecution
    }
    
    @objc public func performHealthCheck() async throws -> Bool {
        if !isHealthy {
            throw SecurityError.xpcServiceError("Service is not healthy")
        }
        return true
    }
}

extension MockXPCService: ResticXPCServiceProtocol {
    public func ping() async -> Bool {
        isHealthy
    }
    
    public func initializeRepository(at url: URL, username: String, password: String) async throws {
        guard isConnected else {
            throw SecurityError.xpcConnectionFailed("Not connected")
        }
        
        if shouldFailExecution {
            throw SecurityError.xpcServiceError("Mock execution failure")
        }
        
        let command = "init"
        lastCommand = command
        commandHistory.append((command, nil))
    }
    
    public func backup(from source: URL, to destination: URL, username: String, password: String) async throws {
        guard isConnected else {
            throw SecurityError.xpcConnectionFailed("Not connected")
        }
        
        if shouldFailExecution {
            throw SecurityError.xpcServiceError("Mock execution failure")
        }
        
        let command = "backup"
        lastCommand = command
        commandHistory.append((command, nil))
    }
    
    public func listSnapshots(username: String, password: String) async throws -> [String] {
        guard isConnected else {
            throw SecurityError.xpcConnectionFailed("Not connected")
        }
        
        if shouldFailExecution {
            throw SecurityError.xpcServiceError("Mock execution failure")
        }
        
        let command = "snapshots"
        lastCommand = command
        commandHistory.append((command, nil))
        
        return ["snapshot1", "snapshot2"]
    }
    
    public func restore(from source: URL, to destination: URL, username: String, password: String) async throws {
        guard isConnected else {
            throw SecurityError.xpcConnectionFailed("Not connected")
        }
        
        if shouldFailExecution {
            throw SecurityError.xpcServiceError("Mock execution failure")
        }
        
        let command = "restore"
        lastCommand = command
        commandHistory.append((command, nil))
    }
    
    public func startAccessing(_ url: URL) -> Bool {
        accessStartCount += 1
        accessedURLs.insert(url)
        return true
    }
    
    public func stopAccessing(_ url: URL) {
        accessStopCount += 1
        accessedURLs.remove(url)
    }
    
    func connect() async throws {
        if shouldFailConnection {
            throw SecurityError.xpcConnectionFailed("Mock connection failure")
        }
        isConnected = true
    }
    
    func executeCommand(_ command: String, withBookmark bookmark: Data?) async throws -> ProcessResult {
        guard isConnected else {
            throw SecurityError.xpcConnectionFailed("Not connected")
        }
        
        if shouldFailExecution {
            throw SecurityError.xpcServiceError("Mock execution failure")
        }
        
        lastCommand = command
        lastBookmark = bookmark
        commandHistory.append((command, bookmark))
        
        return ProcessResult(output: "Mock output", error: "", exitCode: 0)
    }
    
    func validatePermissions() async throws -> Bool {
        guard isConnected else {
            throw SecurityError.xpcConnectionFailed("Not connected")
        }
        return true
    }
}
