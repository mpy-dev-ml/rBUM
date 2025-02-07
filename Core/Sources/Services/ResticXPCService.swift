//
//  ResticXPCService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation
import Security

/// Service for managing Restic operations through XPC
@available(macOS 13.0, *)
public final class ResticXPCService: BaseSandboxedService, Measurable, ResticServiceProtocol {
    // MARK: - Properties
    
    /// XPC connection to the Restic service
    private let connection: NSXPCConnection
    
    /// Serial queue for synchronizing operations
    private let queue: DispatchQueue
    
    /// Current health state of the service
    public private(set) var isHealthy: Bool
    
    /// Currently active security-scoped bookmarks
    private var activeBookmarks: [String: NSData] = [:]
    
    /// Default timeout for operations in seconds
    private let defaultTimeout: TimeInterval = 30.0
    
    /// Maximum number of retry attempts for operations
    private let maxRetries = 3
    
    /// Current interface version for XPC communication
    private let interfaceVersion = 1
    
    // MARK: - Initialization
    /// Initializes a new instance of the ResticXPCService class.
    /// - Parameters:
    ///   - logger: The logger to use for logging messages.
    ///   - securityService: The security service to use for security-related operations.
    public override init(logger: LoggerProtocol, securityService: SecurityServiceProtocol) {
        self.queue = DispatchQueue(label: "dev.mpy.rBUM.resticxpc", qos: .userInitiated)
        self.isHealthy = false // Default to false until connection is established
        
        // Configure XPC connection with enhanced security
        self.connection = NSXPCConnection(serviceName: "dev.mpy.rBUM.ResticService")
        self.connection.remoteObjectInterface = NSXPCInterface(with: ResticXPCProtocol.self)
        
        super.init(logger: logger, securityService: securityService)
        
        // Set up enhanced connection handlers
        configureConnection()
        
        // Start the connection
        self.connection.resume()
        
        // Validate interface version and security
        validateInterface()
    }
    
    deinit {
        cleanupResources()
        connection.invalidationHandler = nil
        connection.interruptionHandler = nil
        connection.invalidate()
    }
    
    // MARK: - Resource Management
    
    /// Start accessing security-scoped resources using the provided bookmarks
    /// - Parameter bookmarks: Dictionary mapping paths to their security-scoped bookmarks
    /// - Throws: ResticXPCError if bookmark resolution or access fails
    private func startAccessingResources(_ bookmarks: [String: NSData]) throws {
        for (path, bookmark) in bookmarks {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark as Data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                throw ResticXPCError.invalidBookmark(path: path)
            }
            
            if isStale {
                throw ResticXPCError.staleBookmark(path: path)
            }
            
            guard url.startAccessingSecurityScopedResource() else {
                throw ResticXPCError.accessDenied(path: path)
            }
            
            activeBookmarks[path] = bookmark
        }
    }
    
    /// Stop accessing all active security-scoped resources and clean up bookmarks
    private func stopAccessingResources() {
        for (path, bookmark) in activeBookmarks {
            var isStale = false
            let url = try? URL(
                resolvingBookmarkData: bookmark as Data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if let url = url {
                url.stopAccessingSecurityScopedResource()
            } else {
                logger.error(
                    "Failed to stop accessing resource: \(path)",
                    file: #file,
                    function: #function,
                    line: #line
                )
            }
        }
        activeBookmarks.removeAll()
    }
    
    /// Clean up resources and invalidate connection
    private func cleanupResources() {
        stopAccessingResources()
    }
}

// MARK: - Connection Management
extension ResticXPCService {
    /// Configure XPC connection with error handlers and security settings
    private func configureConnection() {
        // Set up error handling
        connection.interruptionHandler = { [weak self] in
            self?.handleError(ResticXPCError.serviceUnavailable)
        }
        
        connection.invalidationHandler = { [weak self] in
            self?.handleInvalidation()
        }
    }
    
    /// Handle errors that occur during XPC operations
    /// - Parameter error: The error that occurred
    private func handleError(_ error: Error) {
        isHealthy = false
        logger.error(
            "XPC service error: \(error.localizedDescription)",
            file: #file,
            function: #function,
            line: #line
        )
        // Implement recovery strategy based on error type
        if case ResticXPCError.interfaceVersionMismatch = error {
            // Handle version mismatch
            connection.invalidate()
        }
    }
    
    /// Validate interface version and security settings
    private func validateInterface() {
        guard let service = connection.remoteObjectProxy as? ResticXPCServiceProtocol else {
            handleError(ResticXPCError.connectionFailed)
            return
        }
        
        Task {
            if await service.ping() {
                self.isHealthy = true
            } else {
                handleError(ResticXPCError.serviceUnavailable)
            }
        }
    }
    
    /// Handle XPC connection invalidation
    private func handleInvalidation() {
        logger.error(
            "XPC connection invalidated",
            file: #file,
            function: #function,
            line: #line
        )
        cleanupResources()
        isHealthy = false
    }
    
    /// Handle XPC connection interruption
    private func handleInterruption() {
        logger.error("XPC connection interrupted",
                    file: #file,
                    function: #function,
                    line: #line)
        cleanupResources()
        isHealthy = false
    }
}

// MARK: - Health Check
extension ResticXPCService {
    /// Updates the health status of the service.
    @objc public func updateHealthStatus() async {
        do {
            isHealthy = try await performHealthCheck()
        } catch {
            logger.error("Health check failed: \(error.localizedDescription)",
                        file: #file,
                        function: #function,
                        line: #line)
            isHealthy = false
        }
    }
    
    /// Performs a health check on the service.
    /// - Returns: A boolean indicating whether the service is healthy.
    /// - Throws: An error if the health check fails.
    @objc public func performHealthCheck() async throws -> Bool {
        logger.debug("Performing health check",
                    file: #file,
                    function: #function,
                    line: #line)
        
        // Validate XPC connection
        let isValid = try await securityService.validateXPCConnection(connection)
        
        // Check if connection is valid (NSXPCConnection doesn't have isValid, 
        // but we can check if it's not invalidated)
        if !isValid || connection.invalidationHandler == nil {
            throw SecurityError.xpcValidationFailed("XPC connection is invalidated")
        }
        
        return true
    }
}

// MARK: - Command Execution
@available(macOS 13.0, *)
extension ResticXPCService {
    /// Executes a Restic command with the specified parameters.
    /// - Parameters:
    ///   - command: The Restic command to execute.
    ///   - arguments: Arguments to pass to the command.
    ///   - environment: Environment variables for the command.
    ///   - workingDirectory: Working directory for the command.
    ///   - bookmarks: Security-scoped bookmarks for accessing resources.
    ///   - retryCount: Number of times to retry on failure.
    /// - Returns: A ProcessResult containing the command's output and exit code.
    /// - Throws: ProcessError if the command execution fails.
    public func executeCommand(
        _ command: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String,
        bookmarks: [String: NSData]?,
        retryCount: Int
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            guard let service = connection.remoteObjectProxy as? ResticXPCProtocol else {
                continuation.resume(
                    throwing: ResticXPCError.serviceUnavailable
                )
                return
            }
            
            Task {
                do {
                    // Start accessing resources if bookmarks are provided
                    if let bookmarks = bookmarks {
                        try startAccessingResources(bookmarks)
                    }
                    
                    // Execute command with retry logic
                    var lastError: Error?
                    var attempts = 0
                    
                    repeat {
                        do {
                            let result = try await service.executeCommand(
                                command,
                                arguments: arguments,
                                environment: environment,
                                workingDirectory: workingDirectory,
                                bookmarks: bookmarks,
                                retryCount: retryCount
                            )
                            continuation.resume(returning: result)
                            return
                        } catch {
                            lastError = error
                            attempts += 1
                            
                            if attempts <= retryCount {
                                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 1_000_000_000))
                            }
                        }
                    } while attempts <= retryCount
                    
                    continuation.resume(throwing: lastError ?? ProcessError.executionFailed("Unknown error"))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Create a security-scoped bookmark for a URL
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: The created bookmark data
    /// - Throws: SecurityError if bookmark creation fails
    private func createBookmark(for url: URL) throws -> NSData {
        // Create security-scoped bookmark
        var error: NSError?
        let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil,
            error: &error
        )
        
        if let error = error {
            throw SecurityError.bookmarkCreationFailed("Failed to create bookmark: \(error.localizedDescription)")
        }
        
        return bookmark as NSData? ?? NSData()
    }
    
    /// Execute a command with retry logic
    /// - Parameters:
    ///   - command: Command configuration
    ///   - retryCount: Number of retry attempts remaining
    /// - Returns: Process execution result
    /// - Throws: ProcessError if execution fails
    private func executeWithRetry(
        _ command: XPCCommandConfig,
        retryCount: Int
    ) async throws -> ProcessResult {
        // Execute command with retry logic
        var lastError: Error?
        var attempts = 0
        
        repeat {
            do {
                let result = try await executeCommand(
                    command.command,
                    arguments: command.arguments,
                    environment: command.environment,
                    workingDirectory: command.workingDirectory,
                    bookmarks: command.bookmarks,
                    retryCount: retryCount
                )
                return result
            } catch {
                lastError = error
                attempts += 1
                
                if attempts <= retryCount {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 1_000_000_000))
                }
            }
        } while attempts <= retryCount
        
        throw lastError ?? ProcessError.executionFailed("Unknown error")
    }
}

// MARK: - ResticServiceProtocol Implementation
extension ResticXPCService {
    /// Initializes a new repository at the specified URL.
    /// - Parameter url: The URL where the repository will be initialized.
    /// - Throws: An error if the repository initialization fails.
    public func initializeRepository(at url: URL) async throws {
        logger.info(
            "Initializing repository at \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Initialize repository
        _ = try await executeCommand(
            "init",
            arguments: [],
            environment: [:],
            workingDirectory: url.path,
            bookmarks: nil,
            retryCount: 3
        )
    }
    
    /// Backs up the specified source to the specified destination.
    /// - Parameters:
    ///   - source: The source URL to back up.
    ///   - destination: The destination URL where the backup will be stored.
    /// - Throws: An error if the backup fails.
    public func backup(from source: URL, to destination: URL) async throws {
        logger.info(
            "Backing up \(source.path) to \(destination.path)",
            file: #file,
            function: #function,
            line: #line
        )
        
        let result = try await executeCommand(
            "backup",
            arguments: [source.path],
            environment: [:],
            workingDirectory: destination.path,
            bookmarks: nil,
            retryCount: 3
        )
        
        if !result.succeeded {
            throw ProcessError.executionFailed("Backup command failed with exit code: \(result.exitCode)")
        }
    }
    
    /// Lists the available snapshots.
    /// - Returns: An array of snapshot IDs.
    /// - Throws: An error if the snapshot listing fails.
    public func listSnapshots() async throws -> [String] {
        let result = try await executeCommand(
            "restic",
            arguments: ["snapshots", "--json"],
            environment: [:],
            workingDirectory: "/",
            bookmarks: nil
        )
        // Parse JSON output to extract snapshot IDs
        // This is a simplified implementation
        return result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
    
    /// Restores the specified source to the specified destination.
    /// - Parameters:
    ///   - source: The source URL to restore.
    ///   - destination: The destination URL where the restore will be stored.
    /// - Throws: An error if the restore fails.
    public func restore(from source: URL, to destination: URL) async throws {
        logger.info(
            "Restoring from \(source.path) to \(destination.path)",
            file: #file,
            function: #function,
            line: #line
        )
        
        let result = try await executeCommand(
            "restore",
            arguments: ["latest", "--target", destination.path],
            environment: [:],
            workingDirectory: source.path,
            bookmarks: nil,
            retryCount: 3
        )
        
        if !result.succeeded {
            throw ProcessError.executionFailed("Restore command failed with exit code: \(result.exitCode)")
        }
    }
}
