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
public final class ResticXPCService: BaseSandboxedService, Measurable, ResticServiceProtocol {
    // MARK: - Properties

    /// XPC connection to the Restic service
    var connection: NSXPCConnection?

    /// Serial queue for synchronizing operations
    let queue: DispatchQueue

    /// Current health state of the service
    public private(set) var isHealthy: Bool

    /// Currently active security-scoped bookmarks
    var activeBookmarks: [String: NSData]

    /// Default timeout for operations in seconds
    let defaultTimeout: TimeInterval

    /// Maximum number of retry attempts for operations
    let maxRetries: Int

    /// Current interface version for XPC communication
    let interfaceVersion: Int

    /// Pending operations
    var pendingOperations: [ResticXPCOperation]

    // MARK: - Initialization

    override public init(logger: LoggerProtocol, securityService: SecurityServiceProtocol) {
        queue = DispatchQueue(label: "dev.mpy.rBUM.resticxpc", qos: .userInitiated)
        isHealthy = false
        activeBookmarks = [:]
        defaultTimeout = 30.0
        maxRetries = 3
        interfaceVersion = 1
        pendingOperations = []

        super.init(logger: logger, securityService: securityService)

        do {
            try setupXPCConnection()
        } catch {
            logger.error(
                "Failed to set up XPC connection: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    deinit {
        cleanupResources()
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
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
