import Foundation

/// Service for managing Restic operations through XPC
public final class ResticXPCService: BaseSandboxedService, ResticServiceProtocol, HealthCheckable {
    // MARK: - Properties
    private let xpcConnection: NSXPCConnection
    private let commandQueue: DispatchQueue
    
    public var isHealthy: Bool {
        xpcConnection.isValid
    }
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        xpcConnection: NSXPCConnection? = nil
    ) {
        self.commandQueue = DispatchQueue(label: "dev.mpy.rBUM.resticService", qos: .userInitiated)
        
        if let connection = xpcConnection {
            self.xpcConnection = connection
        } else {
            // Create XPC connection
            let connection = NSXPCConnection(serviceName: "dev.mpy.rBUM.resticService")
            connection.remoteObjectInterface = NSXPCInterface(with: ResticXPCProtocol.self)
            connection.resume()
            self.xpcConnection = connection
        }
        
        super.init(logger: logger, securityService: securityService)
        setupXPCErrorHandler()
    }
    
    deinit {
        xpcConnection.invalidate()
    }
    
    // MARK: - ResticServiceProtocol Implementation
    public func initialize(repository: URL, password: String) async throws {
        try await measure("Initialize Repository") {
            guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
                throw ResticError.xpcConnectionFailed
            }
            
            try await withSafeAccess(to: repository) {
                try await proxy.initialize(repository: repository, password: password)
            }
        }
    }
    
    public func backup(source: URL, to repository: URL) async throws {
        try await measure("Backup Operation") {
            guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
                throw ResticError.xpcConnectionFailed
            }
            
            try await withSafeAccess(to: repository) {
                try await withSafeAccess(to: source) {
                    try await proxy.backup(source: source, repository: repository)
                }
            }
        }
    }
    
    public func restore(from repository: URL, snapshot: String, to destination: URL) async throws {
        try await measure("Restore Operation") {
            guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
                throw ResticError.xpcConnectionFailed
            }
            
            try await withSafeAccess(to: repository) {
                try await withSafeAccess(to: destination) {
                    try await proxy.restore(repository: repository, snapshot: snapshot, destination: destination)
                }
            }
        }
    }
    
    public func listSnapshots(in repository: URL) async throws -> [Snapshot] {
        try await measure("List Snapshots") {
            guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
                throw ResticError.xpcConnectionFailed
            }
            
            return try await withSafeAccess(to: repository) {
                try await proxy.listSnapshots(repository: repository)
            }
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Restic Service Health Check") {
            do {
                guard isHealthy else {
                    logger.error("XPC connection is invalid")
                    return false
                }
                
                guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
                    logger.error("Failed to get XPC proxy")
                    return false
                }
                
                try await proxy.ping()
                logger.info("Restic service health check passed")
                return true
            } catch {
                logger.error("Restic service health check failed: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    // MARK: - Private Helpers
    private func setupXPCErrorHandler() {
        xpcConnection.interruptionHandler = { [weak self] in
            self?.logger.error("XPC connection interrupted")
        }
        
        xpcConnection.invalidationHandler = { [weak self] in
            self?.logger.error("XPC connection invalidated")
        }
    }
}

// MARK: - Restic Errors
public enum ResticError: LocalizedError {
    case xpcConnectionFailed
    case initializationFailed(String)
    case backupFailed(String)
    case restoreFailed(String)
    case snapshotListFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .xpcConnectionFailed:
            return "Failed to establish XPC connection"
        case .initializationFailed(let message):
            return "Repository initialization failed: \(message)"
        case .backupFailed(let message):
            return "Backup operation failed: \(message)"
        case .restoreFailed(let message):
            return "Restore operation failed: \(message)"
        case .snapshotListFailed(let message):
            return "Failed to list snapshots: \(message)"
        }
    }
}
