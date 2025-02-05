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
    private let keychainService: KeychainService
    private let operationQueue: OperationQueue
    private var activeBackups: Set<UUID> = []
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.backupService", attributes: .concurrent)
    
    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(ObjectIdentifier(resticService))
        hasher.combine(ObjectIdentifier(keychainService))
        hasher.combine(activeBackups)
        return hasher.finalize()
    }
    
    public override var description: String {
        return "BackupService(activeBackups: \(activeBackups.count))"
    }
    
    public var isHealthy: Bool {
        // Check if we have any stuck backups
        accessQueue.sync {
            activeBackups.isEmpty
        }
    }
    
    // MARK: - Initialization
    public init(resticService: ResticServiceProtocol, keychainService: KeychainService) {
        self.resticService = resticService
        self.keychainService = keychainService
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = 1
        super.init(logger: <#any LoggerProtocol#>, securityService: <#any SecurityServiceProtocol#>)
    }
    
    // MARK: - BackupServiceProtocol Implementation
    public func initializeRepository(_ repository: Repository) async throws {
        try await measure("Initialize Repository") {
            try await resticService.initializeRepository(at: URL(fileURLWithPath: repository.path))
        }
    }
    
    public func createBackup(to repository: Repository, paths: [String], tags: [String]?) async throws {
        let backupId = UUID()
        accessQueue.async(flags: .barrier) {
            self.activeBackups.insert(backupId)
        }
        
        defer {
            accessQueue.async(flags: .barrier) {
                self.activeBackups.remove(backupId)
            }
        }
        
        try await measure("Create Backup") {
            for path in paths {
                let url = URL(fileURLWithPath: path)
                try await resticService.backup(
                    from: url,
                    to: URL(fileURLWithPath: repository.path)
                )
            }
        }
    }
    
    public func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        try await measure("List Snapshots") {
            let snapshotIds = try await resticService.listSnapshots()
            
            return snapshotIds.map { id in
                ResticSnapshot(
                    id: id,
                    time: Date(),
                    hostname: Host.current().localizedName ?? "Unknown",
                    tags: nil, paths: []
                )
            }
        }
    }
    
    public func restore(snapshot: ResticSnapshot, from repository: Repository, paths: [String], to target: String) async throws {
        try await measure("Restore Snapshot") {
            try await resticService.restore(
                from: URL(fileURLWithPath: repository.path),
                to: URL(fileURLWithPath: target)
            )
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Backup Service Health Check") {
            do {
                // Check dependencies
                let resticHealthy = await resticService.performHealthCheck()
                
                // Check active operations
                let noStuckBackups = accessQueue.sync { activeBackups.isEmpty }
                
                return resticHealthy && noStuckBackups
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
    case backupFailed
    case restoreFailed
    case snapshotListFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidRepository:
            return "Invalid repository configuration"
        case .backupFailed:
            return "Failed to create backup"
        case .restoreFailed:
            return "Failed to restore from snapshot"
        case .snapshotListFailed:
            return "Failed to list snapshots"
        }
    }
}
