//
//  ResticXPCService.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation
import AppKit
import XPC

/// Service for managing Restic operations through XPC
public final class ResticXPCService: BaseSandboxedService, ResticServiceProtocol, HealthCheckable {
    // MARK: - Properties
    private let xpcConnection: NSXPCConnection
    private var isConnected: Bool = false
    
    // MARK: - Initialization
    public override init(logger: LoggerProtocol, securityService: SecurityServiceProtocol) {
        self.xpcConnection = NSXPCConnection(serviceName: "dev.mpy.rBUM.ResticService")
        xpcConnection.remoteObjectInterface = NSXPCInterface(with: ResticXPCProtocol.self)
        super.init(logger: logger, securityService: securityService)
        setupXPCConnection()
    }
    
    deinit {
        xpcConnection.invalidate()
    }
    
    // MARK: - ResticServiceProtocol Implementation
    public func executeCommand(_ command: String) async throws -> ProcessResult {
        try await ensureValidConnection()
        guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
            throw ResticError.xpcConnectionFailed
        }
        return try await proxy.executeCommand(command, withBookmark: nil)
    }
    
    public func initializeRepository(_ url: URL, password: String) async throws {
        try await ensureValidConnection()
        guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
            throw ResticError.xpcConnectionFailed
        }
        _ = try await proxy.executeCommand("init", withBookmark: nil)
    }
    
    public func listSnapshots(for repository: URL) async throws -> [ResticSnapshot] {
        try await ensureValidConnection()
        guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
            throw ResticError.xpcConnectionFailed
        }
        return try await withSafeAccess(to: repository) {
            let snapshots = try await proxy.listSnapshots(repository: repository)
            return snapshots.compactMap { $0 as? ResticSnapshot }
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func isHealthy() -> Bool {
        isConnected
    }
    
    // MARK: - Private Methods
    private func setupXPCConnection() {
        // Configure error handler before resuming
        xpcConnection.resume()
        isConnected = true
        
        // Verify connection is healthy
        Task {
            do {
                guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
                    throw ResticError.xpcConnectionFailed
                }
                try await proxy.ping()
                logger.info("XPC connection established successfully",
                          file: #file,
                          function: #function,
                          line: #line)
            } catch {
                logger.error("Failed to verify XPC connection: \(error.localizedDescription)",
                           file: #file,
                           function: #function,
                           line: #line)
                isConnected = false
            }
        }
    }
    
    private func handleInvalidation() {
        isConnected = false
        logger.error("XPC connection was invalidated",
                    file: #file,
                    function: #function,
                    line: #line)
    }
    
    private func handleInterruption() {
        isConnected = false
        logger.warning("XPC connection was interrupted",
                      file: #file,
                      function: #function,
                      line: #line)
    }
    
    private func ensureValidConnection() async throws {
        guard isConnected else {
            throw ResticError.xpcConnectionFailed
        }
    }
    
    private func withSafeAccess<T>(to url: URL, operation: () async throws -> T) async throws -> T {
        guard startAccessing(url) else {
            throw ResticError.resourceAccessDenied
        }
        defer { stopAccessing(url) }
        return try await operation()
    }
    
    private func measure<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let start = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(start)
        logger.info("\(operation) completed in \(String(format: "%.2f", duration))s",
                   file: #file,
                   function: #function,
                   line: #line)
        return result
    }
}

// MARK: - Restic Errors
public enum ResticError: LocalizedError {
    case xpcConnectionFailed
    case resourceAccessDenied
    case initializationFailed
    case snapshotListingFailed
    
    public var errorDescription: String? {
        switch self {
        case .xpcConnectionFailed:
            return "Failed to establish XPC connection"
        case .resourceAccessDenied:
            return "Access to the requested resource was denied"
        case .initializationFailed:
            return "Failed to initialize Restic repository"
        case .snapshotListingFailed:
            return "Failed to list Restic snapshots"
        }
    }
}
