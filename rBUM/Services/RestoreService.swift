//
//  RestoreService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Service for managing restore operations
final class RestoreService: BaseSandboxedService, RestoreServiceProtocol, HealthCheckable, Measurable {
    // MARK: - Properties
    private let resticService: ResticServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let operationQueue: OperationQueue
    private var activeRestores: Set<UUID> = []
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.restoreService", attributes: .concurrent)
    
    public var isHealthy: Bool {
        // Check if we have any stuck restores
        accessQueue.sync {
            activeRestores.isEmpty
        }
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
            accessQueue.async(flags: .barrier) {
                self.activeRestores.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeRestores.remove(operationId)
                }
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
        await measure("Restore Service Health Check") {
            do {
                // Check dependencies
                let resticHealthy = await resticService.performHealthCheck()
                let keychainHealthy = await keychainService.performHealthCheck()
                
                // Check active operations
                let operationsHealthy = isHealthy
                
                return resticHealthy && keychainHealthy && operationsHealthy
            } catch {
                logger.error("Health check failed: \(error.localizedDescription)",
                           file: #file,
                           function: #function,
                           line: #line)
                return false
            }
        }
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
