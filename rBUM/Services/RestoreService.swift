//
//  RestoreService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Service for managing restore operations
@globalActor actor RestoreActor {
    static let shared = RestoreActor()
}

@RestoreActor
final class RestoreService: BaseSandboxedService, RestoreServiceProtocol, HealthCheckable, Measurable {
    func restore(snapshot: Core.ResticSnapshot, from repository: Core.Repository, paths: [String], to target: String) async throws {
        <#code#>
    }
    
    func listSnapshots(in repository: Core.Repository) async throws -> [Core.ResticSnapshot] {
        <#code#>
    }
    
    // MARK: - Properties
    private let resticService: ResticServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let operationQueue: OperationQueue
    private var activeRestores: Set<UUID> = []
    
    nonisolated public var isHealthy: Bool {
        Task { @RestoreActor in
            await activeRestores.isEmpty
        }.value ?? false
    }
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        resticService: ResticServiceProtocol,
        keychainService: KeychainServiceProtocol
    ) {
        self.resticService = resticService
        self.keychainService = keychainService
        
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "dev.mpy.rBUM.restoreQueue"
        self.operationQueue.maxConcurrentOperationCount = 1
        
        super.init(logger: logger, securityService: securityService)
    }
    
    // MARK: - RestoreServiceProtocol Implementation
    public func restore(from source: URL, to destination: URL) async throws {
        try await measure("Restore Files") {
            // Track restore operation
            let operationId = UUID()
            activeRestores.insert(operationId)
            
            defer {
                activeRestores.remove(operationId)
            }
            
            // Verify permissions
            guard try await verifyPermissions(for: destination) else {
                throw RestoreError.insufficientPermissions
            }
            
            // Execute restore
            try await resticService.restore(from: source, to: destination)
            
            logger.info("Restore completed from \(source.path) to \(destination.path)",
                       file: #file,
                       function: #function,
                       line: #line)
        }
    }
    
    public func listSnapshots() async throws -> [String] {
        try await measure("List Snapshots") {
            return try await resticService.listSnapshots()
        }
    }
    
    public func verifyPermissions(for url: URL) async throws -> Bool {
        try await measure("Verify Permissions") {
            return try await securityService.validateAccess(to: url)
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        // Check all dependencies are healthy
        guard await resticService.performHealthCheck(),
              await keychainService.performHealthCheck() else {
            return false
        }
        
        // Check no stuck restores
        return activeRestores.isEmpty
    }
}

// MARK: - Restore Errors
public enum RestoreError: LocalizedError {
    case insufficientPermissions
    case restoreFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "Insufficient permissions to restore to destination"
        case .restoreFailed(let error):
            return "Restore failed: \(error.localizedDescription)"
        }
    }
}
