import Foundation
import Core

/// Service for executing Restic commands via XPC
public final class ResticCommandService: BaseSandboxedService, ResticServiceProtocol, HealthCheckable {
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
    public func initialize(repository: URL, password: String) async throws {
        try await measure("Initialize Repository") {
            // Store credentials first
            let credentials = KeychainCredentials(repositoryUrl: repository, password: password)
            try keychainService.storeCredentials(credentials)
            
            // Initialize repository
            try await xpcService.initializeRepository(at: repository.path, password: password)
            logger.info("Successfully initialized repository at \(repository.path)")
        }
    }
    
    public func backup(source: URL, to repository: URL) async throws {
        let operationId = UUID()
        
        try await measure("Backup Operation \(operationId)") {
            // Validate repository credentials
            let credentials = try keychainService.retrieveCredentials()
            guard credentials.repositoryUrl == repository else {
                throw ResticError.invalidRepository
            }
            
            // Track operation
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            // Execute backup
            try await xpcService.backup(
                source: source.path,
                to: repository.path,
                password: credentials.password
            )
            
            logger.info("Successfully backed up \(source.path) to \(repository.path)")
        }
    }
    
    public func listSnapshots(in repository: URL) async throws -> [Snapshot] {
        try await measure("List Snapshots") {
            // Validate repository credentials
            let credentials = try keychainService.retrieveCredentials()
            guard credentials.repositoryUrl == repository else {
                throw ResticError.invalidRepository
            }
            
            // Get snapshots
            let snapshots = try await xpcService.listSnapshots(
                in: repository.path,
                password: credentials.password
            )
            
            logger.info("Found \(snapshots.count) snapshots in \(repository.path)")
            return snapshots
        }
    }
    
    public func restore(from repository: URL, snapshot: String, to destination: URL) async throws {
        let operationId = UUID()
        
        try await measure("Restore Operation \(operationId)") {
            // Validate repository credentials
            let credentials = try keychainService.retrieveCredentials()
            guard credentials.repositoryUrl == repository else {
                throw ResticError.invalidRepository
            }
            
            // Track operation
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            // Execute restore
            try await xpcService.restore(
                from: repository.path,
                snapshot: snapshot,
                to: destination.path,
                password: credentials.password
            )
            
            logger.info("Successfully restored snapshot \(snapshot) to \(destination.path)")
        }
    }
    
    public func verify(repository: URL) async throws {
        let operationId = UUID()
        
        try await measure("Verify Repository \(operationId)") {
            // Validate repository credentials
            let credentials = try keychainService.retrieveCredentials()
            guard credentials.repositoryUrl == repository else {
                throw ResticError.invalidRepository
            }
            
            // Track operation
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            // Execute verify
            try await xpcService.verify(
                repository: repository.path,
                password: credentials.password
            )
            
            logger.info("Successfully verified repository at \(repository.path)")
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Restic Command Service Health Check") {
            do {
                // Check dependencies
                guard await xpcService.performHealthCheck(),
                      await keychainService.performHealthCheck() else {
                    return false
                }
                
                // Check for stuck operations
                let stuckOperations = accessQueue.sync { activeOperations }
                if !stuckOperations.isEmpty {
                    logger.warning("Found \(stuckOperations.count) potentially stuck operations")
                    return false
                }
                
                logger.info("Restic command service health check passed")
                return true
            } catch {
                logger.error("Restic command service health check failed: \(error.localizedDescription)")
                return false
            }
        }
    }
}

// MARK: - Restic Errors
public enum ResticError: LocalizedError {
    case invalidRepository
    case operationInProgress
    case snapshotNotFound(String)
    case xpcError(String)
    case verificationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidRepository:
            return "Invalid or unauthorized repository"
        case .operationInProgress:
            return "A Restic operation is already in progress"
        case .snapshotNotFound(let id):
            return "Snapshot not found: \(id)"
        case .xpcError(let message):
            return "XPC error: \(message)"
        case .verificationFailed(let message):
            return "Repository verification failed: \(message)"
        }
    }
}
