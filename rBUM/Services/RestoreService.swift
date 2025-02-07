//
//  RestoreService.swift
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

/// Service for managing restore operations
@globalActor actor RestoreActor {
    static let shared = RestoreActor()
}

@RestoreActor
final class RestoreService: BaseSandboxedService, RestoreServiceProtocol, HealthCheckable, Measurable {
    // MARK: - Properties
    private let resticService: ResticServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let operationQueue: OperationQueue
    private var activeRestores: Set<UUID> = []
    private var _isHealthy: Bool = true
    
    @objc public var isHealthy: Bool {
        get { _isHealthy }
    }
    
    public func updateHealthStatus() async {
        let noActiveRestores = await activeRestores.isEmpty
        let resticHealthy = (try? await resticService.performHealthCheck()) ?? false
        _isHealthy = noActiveRestores && resticHealthy
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
    public func restore(snapshot: ResticSnapshot, from repository: Repository, paths: [String], to target: String) async throws {
        try await measure("Restore Files") {
            // Track restore operation
            let operationId = UUID()
            activeRestores.insert(operationId)
            
            defer {
                activeRestores.remove(operationId)
            }
            
            // Verify permissions
            guard try await verifyPermissions(for: URL(fileURLWithPath: target)) else {
                throw RestoreError.insufficientPermissions
            }
            
            // Execute restore
            try await resticService.restore(
                from: URL(fileURLWithPath: repository.path),
                to: URL(fileURLWithPath: target)
            )
            
            logger.info(
                "Restore completed for snapshot \(snapshot.id) to \(target)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    public func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        try await measure("List Snapshots") {
            let snapshotIds = try await resticService.listSnapshots()
            return snapshotIds.map { id in
                ResticSnapshot(
                    id: id,
                    time: Date(),
                    hostname: ProcessInfo.processInfo.hostName,
                    paths: [repository.path]
                )
            }
        }
    }
    
    public func verifyPermissions(for url: URL) async throws -> Bool {
        try await measure("Verify Permissions") {
            return try await securityService.validateAccess(to: url)
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async throws -> Bool {
        await measure("Restore Service Health Check") {
            await updateHealthStatus()
            return isHealthy
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
