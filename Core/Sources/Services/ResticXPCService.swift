import Foundation
import AppKit
import XPC

/// Service for managing Restic operations through XPC
public final class ResticXPCService: BaseSandboxedService, ResticServiceProtocol, HealthCheckable {
    public func executeCommand(_ command: String) async throws -> ProcessResult {
        try await ensureValidConnection()
        guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
            throw ResticError.xpcConnectionFailed
        }
        return try await proxy.executeCommand(command, withBookmark: nil)
    }
    
    // MARK: - Properties
    private let xpcConnection: NSXPCConnection
    private let commandQueue: DispatchQueue
    private var isConnected: Bool = false
    
    public var isHealthy: Bool {
        isConnected && xpcConnection.remoteObjectProxy != nil
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
            
            // Configure security attributes
            connection.invalidationHandler = { [weak self] in
                self?.handleInvalidation()
            }
            connection.interruptionHandler = { [weak self] in
                self?.handleInterruption()
            }
            
            self.xpcConnection = connection
        }
        
        super.init(logger: logger, securityService: securityService)
        setupXPCConnection()
    }
    
    deinit {
        xpcConnection.invalidate()
    }
    
    // MARK: - ResticServiceProtocol Implementation
    public func initialize(repository: URL, password: String) async throws {
        try await measure("Initialize Repository") {
            try await ensureValidConnection()
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
            try await ensureValidConnection()
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
            try await ensureValidConnection()
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
    
    public func listSnapshots(in repository: URL) async throws -> [ResticSnapshot] {
        try await measure("List Snapshots") {
            try await ensureValidConnection()
            guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
                throw ResticError.xpcConnectionFailed
            }
            return try await withSafeAccess(to: repository) {
                let snapshots = try await proxy.listSnapshots(repository: repository)
                return snapshots.compactMap { $0 as? ResticSnapshot }
            }
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Restic Service Health Check") {
            do {
                try await ensureValidConnection()
                guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
                    throw ResticError.xpcConnectionFailed
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
    
    // MARK: - Private Methods
    private func setupXPCConnection() {
        // Configure error handler before resuming
        xpcConnection.resume()
        isConnected = true
        
        // Verify connection is healthy
        Task {
            do {
                guard let proxy = xpcConnection.remoteObjectProxy as? ResticXPCProtocol else {
                    throw ResticError.xpcConnectionFailed
                }
                try await proxy.ping()
                logger.info("XPC connection established successfully")
            } catch {
                logger.error("Failed to verify XPC connection: \(error.localizedDescription)")
                isConnected = false
            }
        }
    }
    
    private func handleInvalidation() {
        isConnected = false
        logger.error("XPC connection was invalidated")
    }
    
    private func handleInterruption() {
        isConnected = false
        logger.warning("XPC connection was interrupted")
    }
    
    private func ensureValidConnection() async throws {
        guard isConnected else {
            throw ResticError.xpcConnectionFailed
        }
    }
    
    private func withSafeAccess<T>(to url: URL, operation: () async throws -> T) async throws -> T {
        guard startAccessing(url) else {
            throw ResticError.resourceAccessDenied
        }
        defer { stopAccessing(url) }
        return try await operation()
    }
    
    private func measure<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let start = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(start)
        logger.info("\(operation) completed in \(String(format: "%.2f", duration))s")
        return result
    }
}

// MARK: - Restic Errors
public enum ResticError: LocalizedError {
    case xpcConnectionFailed
    case resourceAccessDenied
    
    public var errorDescription: String? {
        switch self {
        case .xpcConnectionFailed:
            return "Failed to establish XPC connection"
        case .resourceAccessDenied:
            return "Access to the requested resource was denied"
        }
    }
}
