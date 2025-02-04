//
//  BackupService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Service for managing backup operations
public final class BackupService: BaseSandboxedService, BackupServiceProtocol, HealthCheckable {
    // MARK: - Properties
    private let resticService: ResticServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let operationQueue: OperationQueue
    private var activeBackups: Set<UUID> = []
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.backupService", attributes: .concurrent)
    
    public var isHealthy: Bool {
        // Check if we have any stuck backups
        accessQueue.sync {
            activeBackups.isEmpty
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
        self.operationQueue.name = "dev.mpy.rBUM.backupQueue"
        self.operationQueue.maxConcurrentOperationCount = 1
        
        super.init(logger: logger, securityService: securityService)
    }
    
    // MARK: - BackupServiceProtocol Implementation
    public func createRepository(at url: URL, password: String) async throws {
        try await measure("Create Repository") {
            // Store credentials first
            let credentials = KeychainCredentials(repositoryUrl: url, password: password)
            try keychainService.storeCredentials(credentials)
            
            // Initialize repository
            try await resticService.initialize(repository: url, password: password)
            
            logger.info("Successfully created repository at \(url.path)")
        }
    }
    
    public func startBackup(source: URL, to repository: URL) async throws -> UUID {
        let backupId = UUID()
        
        try await measure("Start Backup \(backupId)") {
            // Validate repository credentials
            let credentials = try keychainService.retrieveCredentials()
            guard credentials.repositoryUrl == repository else {
                throw BackupError.invalidRepository
            }
            
            // Track backup operation
            accessQueue.async(flags: .barrier) {
                self.activeBackups.insert(backupId)
            }
            
            // Start backup in background
            Task.detached { [weak self] in
                guard let self = self else { return }
                
                do {
                    try await self.resticService.backup(source: source, to: repository)
                    self.logger.info("Backup \(backupId) completed successfully")
                } catch {
                    self.logger.error("Backup \(backupId) failed: \(error.localizedDescription)")
                }
                
                // Remove from active backups
                self.accessQueue.async(flags: .barrier) {
                    self.activeBackups.remove(backupId)
                }
            }
            
            logger.info("Started backup \(backupId) from \(source.path) to \(repository.path)")
        }
        
        return backupId
    }
    
    public func cancelBackup(_ id: UUID) {
        accessQueue.async(flags: .barrier) {
            if activeBackups.contains(id) {
                activeBackups.remove(id)
                logger.info("Cancelled backup \(id)")
            } else {
                logger.warning("Attempted to cancel non-existent backup \(id)")
            }
        }
    }
    
    public func listSnapshots(in repository: URL) async throws -> [Snapshot] {
        try await measure("List Snapshots") {
            // Validate repository credentials
            let credentials = try keychainService.retrieveCredentials()
            guard credentials.repositoryUrl == repository else {
                throw BackupError.invalidRepository
            }
            
            return try await resticService.listSnapshots(in: repository)
        }
    }
    
    public func restore(snapshot: String, from repository: URL, to destination: URL) async throws {
        try await measure("Restore Snapshot") {
            // Validate repository credentials
            let credentials = try keychainService.retrieveCredentials()
            guard credentials.repositoryUrl == repository else {
                throw BackupError.invalidRepository
            }
            
            try await resticService.restore(from: repository, snapshot: snapshot, to: destination)
            logger.info("Successfully restored snapshot \(snapshot) to \(destination.path)")
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Backup Service Health Check") {
            do {
                // Check dependencies
                guard await resticService.performHealthCheck(),
                      await keychainService.performHealthCheck() else {
                    return false
                }
                
                // Check for stuck backups
                let stuckBackups = accessQueue.sync { activeBackups }
                if !stuckBackups.isEmpty {
                    logger.warning("Found \(stuckBackups.count) potentially stuck backups")
                    return false
                }
                
                logger.info("Backup service health check passed")
                return true
            } catch {
                logger.error("Backup service health check failed: \(error.localizedDescription)")
                return false
            }
        }
    }
}

// MARK: - Backup Errors
public enum BackupError: LocalizedError {
    case invalidRepository
    case backupInProgress
    case snapshotNotFound(String)
    case restoreFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidRepository:
            return "Invalid or unauthorized repository"
        case .backupInProgress:
            return "A backup operation is already in progress"
        case .snapshotNotFound(let id):
            return "Snapshot not found: \(id)"
        case .restoreFailed(let message):
            return "Restore operation failed: \(message)"
        }
    }
}
