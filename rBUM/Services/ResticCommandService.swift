//
//  ResticCommandService.swift
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

/// Service for executing Restic commands via XPC
public final class ResticCommandService: BaseSandboxedService, ResticServiceProtocol, HealthCheckable, Measurable {
    // MARK: - Properties
    private let xpcService: ResticXPCServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let operationQueue: OperationQueue
    private var activeOperations: Set<UUID> = []
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.resticCommand", attributes: .concurrent)
    
    public var isHealthy: Bool {
        // Check if we have any stuck operations
        accessQueue.sync {
            activeOperations.isEmpty
        }
    }
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        xpcService: ResticXPCServiceProtocol,
        keychainService: KeychainServiceProtocol
    ) {
        self.xpcService = xpcService
        self.keychainService = keychainService
        
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "dev.mpy.rBUM.resticQueue"
        self.operationQueue.maxConcurrentOperationCount = 1
        
        super.init(logger: logger, securityService: securityService)
    }
    
    // MARK: - ResticServiceProtocol Implementation
    public func initializeRepository(at url: URL) async throws {
        try await measure("Initialize Repository") {
            // Track operation
            let operationId = UUID()
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            // Execute via XPC
            try await xpcService.initializeRepository(
                at: url,
                username: url.lastPathComponent,  // Use appropriate credentials here
                password: UUID().uuidString      // Use appropriate credentials here
            )
            
            logger.info("Repository initialized at \(url.path)",
                       file: #file,
                       function: #function,
                       line: #line)
        }
    }
    
    public func backup(from source: URL, to destination: URL) async throws {
        try await measure("Create Backup") {
            // Track operation
            let operationId = UUID()
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            // Execute backup via XPC
            try await xpcService.backup(
                from: source,
                to: destination,
                username: destination.lastPathComponent,  // Use appropriate credentials here
                password: UUID().uuidString              // Use appropriate credentials here
            )
            
            logger.info("Backup completed from \(source.path) to \(destination.path)",
                       file: #file,
                       function: #function,
                       line: #line)
        }
    }
    
    public func listSnapshots() async throws -> [String] {
        try await measure("List Snapshots") {
            // Execute via XPC
            return try await xpcService.listSnapshots(
                username: "default",  // Use appropriate credentials here
                password: UUID().uuidString  // Use appropriate credentials here
            )
        }
    }
    
    public func restore(from source: URL, to destination: URL) async throws {
        try await measure("Restore Backup") {
            // Track operation
            let operationId = UUID()
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            // Execute restore via XPC
            try await xpcService.restore(
                from: source,
                to: destination,
                username: source.lastPathComponent,  // Use appropriate credentials here
                password: UUID().uuidString          // Use appropriate credentials here
            )
            
            logger.info("Restore completed from \(source.path) to \(destination.path)",
                       file: #file,
                       function: #function,
                       line: #line)
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Restic Command Service Health Check") {
            do {
                // Check XPC service
                let xpcHealthy = await xpcService.ping()
                guard xpcHealthy else {
                    return false
                }
                
                // Check active operations
                let operationsHealthy = isHealthy
                
                return xpcHealthy && operationsHealthy
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
