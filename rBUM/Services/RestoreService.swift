//
//  RestoreService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Service for managing restore operations
public final class RestoreService: BaseSandboxedService, RestoreServiceProtocol, HealthCheckable {
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
    public func listSnapshots(in repository: URL) async throws -> [Snapshot] {
        try await measure("List Snapshots") {
            // Validate repository credentials
            let credentials = try keychainService.retrieveCredentials()
            guard credentials.repositoryUrl == repository else {
                throw RestoreError.invalidRepository
            }
            
            return try await resticService.listSnapshots(in: repository)
        }
    }
    
    public func startRestore(snapshot: String, from repository: URL, to destination: URL) async throws -> UUID {
        let restoreId = UUID()
        
        try await measure("Start Restore \(restoreId)") {
            // Validate repository credentials
            let credentials = try keychainService.retrieveCredentials()
            guard credentials.repositoryUrl == repository else {
                throw RestoreError.invalidRepository
            }
            
            // Track restore operation
            accessQueue.async(flags: .barrier) {
                self.activeRestores.insert(restoreId)
            }
            
            // Start restore in background
            Task.detached { [weak self] in
                guard let self = self else { return }
                
                do {
                    try await self.resticService.restore(from: repository, snapshot: snapshot, to: destination)
                    self.logger.info("Restore \(restoreId) completed successfully")
                } catch {
                    self.logger.error("Restore \(restoreId) failed: \(error.localizedDescription)")
                }
                
                // Remove from active restores
                self.accessQueue.async(flags: .barrier) {
                    self.activeRestores.remove(restoreId)
                }
            }
            
            logger.info("Started restore \(restoreId) of snapshot \(snapshot) to \(destination.path)")
        }
        
        return restoreId
    }
    
    public func cancelRestore(_ id: UUID) {
        accessQueue.async(flags: .barrier) {
            if activeRestores.contains(id) {
                activeRestores.remove(id)
                logger.info("Cancelled restore \(id)")
            } else {
                logger.warning("Attempted to cancel non-existent restore \(id)")
            }
        }
    }
    
    public func validateRestoreLocation(_ url: URL) async throws -> Bool {
        try await measure("Validate Restore Location") {
            do {
                // Check if location is accessible
                guard await securityService.checkAccess(to: url) else {
                    logger.warning("No access to restore location: \(url.path)")
                    return false
                }
                
                // Check if location has enough space
                let attributes = try FileManager.default.attributesOfFileSystem(forPath: url.path)
                guard let freeSpace = attributes[.systemFreeSize] as? Int64,
                      freeSpace > 1_000_000_000 /* 1GB minimum */ else {
                    logger.warning("Insufficient space at restore location: \(url.path)")
                    return false
                }
                
                logger.info("Successfully validated restore location: \(url.path)")
                return true
            } catch {
                logger.error("Failed to validate restore location: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Restore Service Health Check") {
            do {
                // Check dependencies
                guard await resticService.performHealthCheck(),
                      await keychainService.performHealthCheck() else {
                    return false
                }
                
                // Check for stuck restores
                let stuckRestores = accessQueue.sync { activeRestores }
                if !stuckRestores.isEmpty {
                    logger.warning("Found \(stuckRestores.count) potentially stuck restores")
                    return false
                }
                
                logger.info("Restore service health check passed")
                return true
            } catch {
                logger.error("Restore service health check failed: \(error.localizedDescription)")
                return false
            }
        }
    }
}

// MARK: - Restore Errors
public enum RestoreError: LocalizedError {
    case invalidRepository
    case restoreInProgress
    case snapshotNotFound(String)
    case destinationError(String)
    case insufficientSpace
    
    public var errorDescription: String? {
        switch self {
        case .invalidRepository:
            return "Invalid or unauthorized repository"
        case .restoreInProgress:
            return "A restore operation is already in progress"
        case .snapshotNotFound(let id):
            return "Snapshot not found: \(id)"
        case .destinationError(let message):
            return "Destination error: \(message)"
        case .insufficientSpace:
            return "Insufficient space at restore location"
        }
    }
}
