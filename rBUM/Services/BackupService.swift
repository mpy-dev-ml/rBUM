//
//  BackupService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Service for managing backup operations
public final class BackupService: BaseSandboxedService, BackupServiceProtocol, HealthCheckable, Measurable {
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
    public func initializeRepository(_ repository: Repository) async throws {
        try await measure("Initialize Repository") {
            try await resticService.initializeRepository(at: URL(fileURLWithPath: repository.path))
            
            logger.info("Repository initialized at \(repository.path)",
                       file: #file,
                       function: #function,
                       line: #line)
        }
    }
    
    public func createBackup(to repository: Repository, paths: [String], tags: [String]?) async throws {
        try await measure("Create Backup") {
            // Track backup operation
            let operationId = UUID()
            accessQueue.async(flags: .barrier) {
                self.activeBackups.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeBackups.remove(operationId)
                }
            }
            
            // Create backup
            for path in paths {
                guard let url = URL(string: path) else {
                    logger.error("Invalid path: \(path)",
                               file: #file,
                               function: #function,
                               line: #line)
                    throw BackupError.invalidPath(path)
                }
                
                try await resticService.backup(
                    from: url,
                    to: URL(fileURLWithPath: repository.path)
                )
            }
        }
    }
    
    public func listSnapshots(in repository: Repository) async throws -> [Snapshot] {
        try await measure("List Snapshots") {
            let snapshotIds = try await resticService.listSnapshots()
            
            return snapshotIds.map { id in
                Snapshot(
                    id: id,
                    time: Date(),
                    repository: repository,
                    tags: nil
                )
            }
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Backup Service Health Check") {
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

// MARK: - Backup Errors
public enum BackupError: LocalizedError {
    case invalidRepository
    case invalidPath(String)
    case backupFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidRepository:
            return "Invalid repository configuration"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .backupFailed(let error):
            return "Backup failed: \(error.localizedDescription)"
        }
    }
}
