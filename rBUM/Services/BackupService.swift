//
//  BackupService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Service for managing backup operations

public final class BackupService: BaseSandboxedService, BackupServiceProtocol, HealthCheckable, Measurable, @unchecked Sendable {
    // MARK: - Properties
    private let resticService: ResticServiceProtocol
    private let keychainService: KeychainService
    private let operationQueue: OperationQueue
    private actor BackupState {
        var activeBackups: Set<UUID> = []
        private(set) var cachedHealthStatus: Bool = true
        
        func insert(_ id: UUID) {
            activeBackups.insert(id)
            cachedHealthStatus = activeBackups.isEmpty
        }
        
        func remove(_ id: UUID) {
            activeBackups.remove(id)
            cachedHealthStatus = activeBackups.isEmpty
        }
        
        var isEmpty: Bool {
            activeBackups.isEmpty
        }
        
        func updateCachedHealth(_ value: Bool) {
            cachedHealthStatus = value
        }
    }
    private let backupState = BackupState()
    
    @objc public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(ObjectIdentifier(resticService))
        hasher.combine(ObjectIdentifier(keychainService))
        return hasher.finalize()
    }
    
    @objc public override var description: String {
        "BackupService"
    }
    
    @objc public var isHealthy: Bool {
        get {
            // Return the cached value synchronously
            Task {
                await updateHealthStatus()
            }
            // Return the synchronous cached value
            Task {
                await backupState.cachedHealthStatus
            }.value ?? true // Default to true if task fails
        }
    }
    
    public func updateHealthStatus() async {
        let status = await backupState.isEmpty && 
                    (try? await resticService.performHealthCheck()) ?? false
        await backupState.updateCachedHealth(status)
    }
    
    // MARK: - Initialization
    public init(resticService: ResticServiceProtocol, keychainService: KeychainService) {
        self.resticService = resticService
        self.keychainService = keychainService
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = 1
        
        let logger = OSLogger(category: "backup")
        
        // Create a temporary security service for bootstrapping
        let tempSecurityService = SecurityService(logger: logger, xpcService: MockResticXPCService())
        
        // Now create the real XPC service with the temporary security service
        let xpcService = ResticXPCService(logger: logger, securityService: tempSecurityService)
        
        // Finally create the real security service with the real XPC service
        let securityService = SecurityService(logger: logger, xpcService: xpcService as! ResticXPCServiceProtocol)
        
        super.init(logger: logger, securityService: securityService)
    }
    
    // MARK: - BackupServiceProtocol Implementation
    public func initializeRepository(_ repository: Repository) async throws {
        try await measure("Initialize Repository") {
            try await resticService.initializeRepository(at: URL(fileURLWithPath: repository.path))
        }
    }
    
    public func createBackup(to repository: Repository, paths: [String], tags: [String]?) async throws {
        let backupId = UUID()
        await backupState.insert(backupId)
        
        defer {
            Task {
                await backupState.remove(backupId)
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
                let resticHealthy = try await resticService.performHealthCheck()
                
                // Check active operations
                let noStuckBackups = await backupState.isEmpty
                
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
