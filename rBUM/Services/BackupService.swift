//
//  BackupService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Core
import Foundation

/// Service for managing backup operations
public final class BackupService: BaseSandboxedService, BackupServiceProtocol, HealthCheckable, Measurable, @unchecked Sendable {
    // MARK: - Properties
    private let resticService: ResticServiceProtocol
    private let keychainService: KeychainService
    private let operationQueue: OperationQueue
    
    private actor BackupState {
        var activeBackups: Set<UUID> = []
        var cachedHealthStatus: Bool = true
        
        func insert(_ id: UUID) {
            activeBackups.insert(id)
            updateCachedHealth()
        }
        
        func remove(_ id: UUID) {
            activeBackups.remove(id)
            updateCachedHealth()
        }
        
        var isEmpty: Bool {
            activeBackups.isEmpty
        }
        
        private func updateCachedHealth() {
            cachedHealthStatus = activeBackups.isEmpty
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
    
    @objc public private(set) var isHealthy: Bool = true
    
    public func updateHealthStatus() async {
        let isEmpty = await backupState.isEmpty
        let resticHealthy = (try? await resticService.performHealthCheck()) ?? false
        isHealthy = isEmpty && resticHealthy
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
        
        try await measure("Create Backup") {
            // Track backup operation
            await backupState.insert(backupId)
            
            defer {
                Task {
                    await backupState.remove(backupId)
                }
            }
            
            // Create URLs
            let urls = paths.map { URL(fileURLWithPath: $0) }
            let repoURL = URL(fileURLWithPath: repository.path)
            
            // Execute backup
            for url in urls {
                try await resticService.backup(from: url, to: repoURL)
            }
            
            logger.info("Backup completed to \(repository.path)", file: #file, function: #function, line: #line)
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
    public func performHealthCheck() async throws -> Bool {
        await measure("Backup Service Health Check") {
            await updateHealthStatus()
            return isHealthy
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
