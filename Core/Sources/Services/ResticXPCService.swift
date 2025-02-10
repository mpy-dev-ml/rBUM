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
@objc public final class ResticXPCService: NSObject, ResticServiceProtocol, XPCConnectionStateDelegate {
    // MARK: - Properties

    /// XPC connection manager
    private let connectionManager: XPCConnectionManager

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

    /// Message queue for handling XPC commands
    private let messageQueue: XPCMessageQueue

    /// Task for processing the message queue
    private var queueProcessor: Task<Void, Never>?

    /// Health monitor for service status
    private let healthMonitor: XPCHealthMonitor

    // MARK: - Initialization

    @objc public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol
    ) {
        self.logger = logger
        self.securityService = securityService
        queue = DispatchQueue(label: "dev.mpy.rBUM.resticXPC", qos: .userInitiated)
        isHealthy = false
        activeBookmarks = [:]
        messageQueue = XPCMessageQueue(logger: logger)

        // Initialize connection manager
        connectionManager = XPCConnectionManager(
            logger: logger,
            securityService: securityService
        )

        // Initialize health monitor
        healthMonitor = XPCHealthMonitor(
            connectionManager: connectionManager,
            logger: logger
        )

        super.init()

        // Set up connection manager delegate
        Task {
            await connectionManager.setDelegate(self)
            try await establishConnection()
            await healthMonitor.startMonitoring()
        }
    }

    deinit {
        Task {
            await healthMonitor.stopMonitoring()
        }
    }

    // MARK: - Connection Management

    private func establishConnection() async throws {
        _ = try await connectionManager.establishConnection()
        isHealthy = true
    }

    // MARK: - XPCConnectionStateDelegate

    func connectionStateDidChange(from oldState: XPCConnectionState, to newState: XPCConnectionState) {
        switch newState {
        case .active:
            isHealthy = true
            startQueueProcessor()
            Task {
                await healthMonitor.startMonitoring()
            }
        case .failed:
            isHealthy = false
            stopQueueProcessor()
            Task {
                await healthMonitor.stopMonitoring()
            }
        default:
            isHealthy = false
        }

        logger.info("XPC connection state changed: \(oldState) -> \(newState)", privacy: .public)
    }

    // MARK: - Command Execution

    private func executeCommand(_ config: XPCCommandConfig) async throws -> ProcessResult {
        let connection = try await connectionManager.establishConnection()

        guard let remote = connection.remoteObjectProxyWithErrorHandler({ error in
            self.logger.error("Remote proxy error: \(error.localizedDescription)", privacy: .public)
        }) as? ResticXPCProtocol else {
            throw ResticXPCError.invalidRemoteObject
        }

        return try await remote.execute(config: config, progress: ProgressTracker())
    }

    // MARK: - ResticServiceProtocol Implementation

    @objc public func initializeRepository(at url: URL) async throws {
        try await validateConnection()
        try await validatePermissions(for: url)

        let result = try await executeCommand(
            XPCCommandConfig(
                command: "init",
                arguments: ["--repository", url.path],
                workingDirectory: url
            )
        )

        guard result.status == 0 else {
            throw ResticError.initializationFailed(result.error ?? "Unknown error")
        }
    }

    @objc public func backup(from source: URL, to destination: URL) async throws {
        try await validateConnection()
        try await validatePermissions(for: [source, destination])

        let config = XPCCommandConfig(
            command: "backup",
            arguments: ["--repository", destination.path, source.path],
            workingDirectory: source
        )

        let messageId = await enqueueCommand(config)

        // Wait for completion
        for try await notification in NotificationCenter.default.notifications(named: .xpcCommandCompleted) {
            guard let notificationMessageId = notification.userInfo?["messageId"] as? UUID,
                  notificationMessageId == messageId
            else {
                continue
            }

            if let result = notification.userInfo?["result"] as? ProcessResult {
                guard result.status == 0 else {
                    throw ResticError.backupFailed(result.error ?? "Unknown error")
                }
                return
            }
        }
    }

    @objc public func listSnapshots() async throws -> [String] {
        try await validateConnection()

        let result = try await executeCommand(
            XPCCommandConfig(
                command: "snapshots",
                arguments: ["--json"],
                workingDirectory: nil
            )
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
            XPCCommandConfig(
                command: "restore",
                arguments: ["latest", "--target", destination.path, "--repository", source.path],
                workingDirectory: destination
            )
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
    case invalidRemoteObject

    public var errorDescription: String? {
        switch self {
        case .connectionNotEstablished:
            "XPC connection not established"
        case .connectionInterrupted:
            "XPC connection interrupted"
        case let .invalidBookmark(path):
            "Invalid security-scoped bookmark for path: \(path)"
        case let .staleBookmark(path):
            "Stale security-scoped bookmark for path: \(path)"
        case let .accessDenied(path):
            "Access denied to path: \(path)"
        case .missingServiceName:
            "XPC service name not found in Info.plist"
        case .serviceUnavailable:
            "XPC service is not available"
        case .operationTimeout:
            "Operation timed out"
        case .operationCancelled:
            "Operation was cancelled"
        case .invalidResponse:
            "Invalid response from XPC service"
        case .invalidArguments:
            "Invalid arguments provided to XPC service"
        case .invalidRemoteObject:
            "Invalid remote object"
        }
    }
}
