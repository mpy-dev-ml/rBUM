import Foundation
import Security

/// Service for managing Restic operations through XPC
///
/// The ResticXPCService provides a secure interface for executing Restic commands
/// through XPC communication. It handles:
/// - Connection management
/// - Security-scoped resource access
/// - Error handling and recovery
/// - Operation tracking
///
/// Key features:
/// - Secure XPC communication
/// - Resource cleanup
/// - Error recovery
/// - Operation management
///
/// Example usage:
/// ```swift
/// let service = ResticXPCService(logger: logger, securityService: security)
///
/// // Execute backup
/// try await service.backup(from: sourceURL, to: destURL)
///
/// // Check health
/// if await service.performHealthCheck() {
///     print("Service is healthy")
/// }
/// ```
///
/// Implementation notes:
/// 1. Uses XPC for secure inter-process communication
/// 2. Manages security-scoped resources
/// 3. Handles connection interruptions
/// 4. Provides operation tracking
@available(macOS 13.0, *)
@objc public final class ResticXPCService: NSObject, ResticServiceProtocol {
    // MARK: - Properties

    /// XPC connection to the Restic service
    @objc private var connection: NSXPCConnection?

    /// Serial queue for synchronizing operations
    @objc private let queue: DispatchQueue

    /// Current health state of the service
    @objc public private(set) var isHealthy: Bool

    /// Currently active security-scoped bookmarks
    @objc private var activeBookmarks: [String: NSData]
    
    /// Logger for service operations
    @objc private let logger: LoggerProtocol
    
    /// Security service for handling permissions
    @objc private let securityService: SecurityServiceProtocol
    
    // MARK: - Initialization
    
    /// Initialize a new Restic XPC service
    /// - Parameters:
    ///   - logger: Logger for service operations
    ///   - securityService: Security service for handling permissions
    @objc public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol
    ) {
        self.logger = logger
        self.securityService = securityService
        self.queue = DispatchQueue(label: "dev.mpy.rBUM.resticXPC", qos: .userInitiated)
        self.isHealthy = false
        self.activeBookmarks = [:]
        super.init()
        
        setupConnection()
    }
    
    // MARK: - ResticServiceProtocol Implementation
    
    @objc public func initializeRepository(at url: URL) async throws {
        try await validateConnection()
        try await validatePermissions(for: url)
        
        let result = try await executeCommand(
            "init",
            arguments: ["--repository", url.path],
            at: url
        )
        
        guard result.status == 0 else {
            throw ResticError.initializationFailed(result.error ?? "Unknown error")
        }
    }
    
    @objc public func backup(from source: URL, to destination: URL) async throws {
        try await validateConnection()
        try await validatePermissions(for: [source, destination])
        
        let result = try await executeCommand(
            "backup",
            arguments: [source.path, "--repository", destination.path],
            at: destination
        )
        
        guard result.status == 0 else {
            throw ResticError.backupFailed(result.error ?? "Unknown error")
        }
    }
    
    @objc public func listSnapshots() async throws -> [String] {
        try await validateConnection()
        
        let result = try await executeCommand(
            "snapshots",
            arguments: ["--json"],
            at: nil
        )
        
        guard result.status == 0 else {
            throw ResticError.snapshotListFailed(result.error ?? "Unknown error")
        }
        
        return try parseSnapshots(from: result.output)
    }
    
    @objc public func restore(from source: URL, to destination: URL) async throws {
        try await validateConnection()
        try await validatePermissions(for: [source, destination])
        
        let result = try await executeCommand(
            "restore",
            arguments: ["latest", "--target", destination.path, "--repository", source.path],
            at: destination
        )
        
        guard result.status == 0 else {
            throw ResticError.restoreFailed(result.error ?? "Unknown error")
        }
    }
}

// MARK: - Errors

/// Errors that can occur during XPC operations
public enum ResticXPCError: LocalizedError {
    case connectionNotEstablished
    case connectionInterrupted
    case invalidBookmark(path: String)
    case staleBookmark(path: String)
    case accessDenied(path: String)
    case missingServiceName
    case serviceUnavailable
    case operationTimeout
    case operationCancelled
    case invalidResponse
    case invalidArguments
    
    public var errorDescription: String? {
        switch self {
        case .connectionNotEstablished:
            return "XPC connection not established"
        case .connectionInterrupted:
            return "XPC connection interrupted"
        case .invalidBookmark(let path):
            return "Invalid security-scoped bookmark for path: \(path)"
        case .staleBookmark(let path):
            return "Stale security-scoped bookmark for path: \(path)"
        case .accessDenied(let path):
            return "Access denied to path: \(path)"
        case .missingServiceName:
            return "XPC service name not found in Info.plist"
        case .serviceUnavailable:
            return "XPC service is not available"
        case .operationTimeout:
            return "Operation timed out"
        case .operationCancelled:
            return "Operation was cancelled"
        case .invalidResponse:
            return "Invalid response from XPC service"
        case .invalidArguments:
            return "Invalid arguments provided to XPC service"
        }
    }
}
