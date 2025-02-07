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
    private var connection: NSXPCConnection?

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

    /// Pending operations
    private var pendingOperations: [ResticXPCOperation] = []

    // MARK: - Initialization

    /// Initializes a new instance of the ResticXPCService class.
    /// - Parameters:
    ///   - logger: The logger to use for logging messages.
    ///   - securityService: The security service to use for security-related operations.
    override public init(logger: LoggerProtocol, securityService: SecurityServiceProtocol) {
        queue = DispatchQueue(label: "dev.mpy.rBUM.resticxpc", qos: .userInitiated)
        isHealthy = false // Default to false until connection is established

        super.init(logger: logger, securityService: securityService)

        // Set up XPC connection
        do {
            try setupXPCConnection()
        } catch {
            logger.error("Failed to set up XPC connection: \(error.localizedDescription)",
                         file: #file,
                         function: #function,
                         line: #line)
        }
    }

    deinit {
        cleanupResources()
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
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

            if let url {
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

    // MARK: - Connection Management

    private func setupXPCConnection() throws {
        // Create connection
        let connection = try createXPCConnection()
        
        // Configure connection
        try configureXPCConnection(connection)
        
        // Set up handlers
        setupConnectionHandlers(connection)
        
        // Resume connection
        connection.resume()
        
        // Store connection
        self.connection = connection
    }
    
    private func createXPCConnection() throws -> NSXPCConnection {
        guard let serviceName = Bundle.main.object(forInfoDictionaryKey: "XPCServiceName") as? String else {
            throw ResticXPCError.missingServiceName
        }
        
        let connection = NSXPCConnection(serviceName: serviceName)
        
        // Set up security attributes
        connection.auditSessionIdentifier = au_session_self()
        
        return connection
    }
    
    private func configureXPCConnection(_ connection: NSXPCConnection) throws {
        // Configure interfaces
        try configureRemoteInterface(for: connection)
        try configureExportedInterface(for: connection)
        
        // Configure security
        try configureConnectionSecurity(for: connection)
    }
    
    private func configureRemoteInterface(for connection: NSXPCConnection) throws {
        let interface = NSXPCInterface(with: ResticXPCServiceProtocol.self)
        
        // Configure allowed classes
        let allowedClasses = [
            NSArray.self,
            NSDictionary.self,
            NSString.self,
            NSNumber.self,
            NSData.self,
            NSURL.self,
            NSError.self
        ]
        
        // Configure class requirements
        interface.setClasses(
            NSSet(array: allowedClasses) as! Set<AnyHashable>,
            for: #selector(ResticXPCServiceProtocol.execute(_:arguments:environment:reply:)),
            argumentIndex: 2,
            ofReply: false
        )
        
        connection.remoteObjectInterface = interface
    }
    
    private func configureExportedInterface(for connection: NSXPCConnection) throws {
        let interface = NSXPCInterface(with: ResticXPCProtocol.self)
        
        // Configure allowed classes for progress updates
        interface.setClasses(
            NSSet(array: [NSProgress.self]) as! Set<AnyHashable>,
            for: #selector(ResticXPCProtocol.updateProgress(_:)),
            argumentIndex: 0,
            ofReply: false
        )
        
        connection.exportedInterface = interface
    }
    
    private func configureConnectionSecurity(for connection: NSXPCConnection) throws {
        // Set entitlement requirements
        connection.remoteObjectInterface?.setClasses(
            NSSet(array: [NSString.self]) as! Set<AnyHashable>,
            for: #selector(ResticXPCServiceProtocol.validateEntitlements(_:reply:)),
            argumentIndex: 0,
            ofReply: false
        )
        
        // Validate connection security
        try validateConnectionSecurity(connection)
    }
    
    private func validateConnectionSecurity(_ connection: NSXPCConnection) throws {
        // Validate audit session
        guard connection.auditSessionIdentifier != AU_DEFAUDITSID else {
            throw ResticXPCError.invalidAuditSession
        }
        
        // Validate entitlements
        guard try validateEntitlements() else {
            throw ResticXPCError.missingEntitlements
        }
    }
    
    private func setupConnectionHandlers(_ connection: NSXPCConnection) {
        // Set up invalidation handler
        connection.invalidationHandler = { [weak self] in
            self?.handleConnectionInvalidation()
        }
        
        // Set up interruption handler
        connection.interruptionHandler = { [weak self] in
            self?.handleConnectionInterruption()
        }
    }
    
    private func handleConnectionInvalidation() {
        Task { @MainActor in
            // Log invalidation
            logger.error("XPC connection invalidated", metadata: [
                "service": .string("ResticXPCService")
            ])
            
            // Clean up resources
            cleanupResources()
            
            // Notify delegate
            // delegate?.xpcServiceDidInvalidate(self)
            
            // Reset connection
            connection = nil
        }
    }
    
    private func handleConnectionInterruption() {
        Task { @MainActor in
            // Log interruption
            logger.error("XPC connection interrupted", metadata: [
                "service": .string("ResticXPCService")
            ])
            
            // Attempt reconnection
            do {
                try reconnect()
            } catch {
                logger.error("Failed to reconnect", metadata: [
                    "error": .string(error.localizedDescription)
                ])
                
                // Notify delegate of failure
                // delegate?.xpcService(self, didFailWithError: error)
            }
        }
    }
    
    private func reconnect() throws {
        // Clean up existing connection
        cleanupResources()
        
        // Create new connection
        try setupXPCConnection()
        
        // Validate connection
        try validateConnection()
        
        // Log reconnection
        logger.info("Successfully reconnected to XPC service", metadata: [
            "service": .string("ResticXPCService")
        ])
        
        // Notify delegate
        // delegate?.xpcServiceDidReconnect(self)
    }
    
    private func validateConnection() throws {
        guard let connection = connection else {
            throw ResticXPCError.connectionNotEstablished
        }
        
        // Check connection state
        guard connection.isValid else {
            throw ResticXPCError.invalidConnection
        }
        
        // Ping service
        try ping()
    }
    
    private func ping() throws {
        guard let service = connection?.remoteObjectProxy as? ResticXPCServiceProtocol else {
            throw ResticXPCError.invalidService
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var pingError: Error?
        
        service.ping { error in
            pingError = error
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + .seconds(5))
        
        if let error = pingError {
            throw error
        }
    }
    
    private func executeCommand(
        _ command: String,
        arguments: [String],
        environment: [String: String]
    ) async throws -> ProcessResult {
        guard let service = connection?.remoteObjectProxy as? ResticXPCServiceProtocol else {
            throw ResticXPCError.invalidService
        }
        
        // Create operation
        let operation = ResticXPCOperation(
            command: command,
            arguments: arguments,
            environment: environment
        )
        
        // Add to pending operations
        pendingOperations.append(operation)
        
        defer {
            // Remove from pending operations
            pendingOperations.removeAll { $0 === operation }
        }
        
        // Execute command
        return try await withCheckedThrowingContinuation { continuation in
            service.execute(command, arguments: arguments, environment: environment) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    private func validateEntitlements() throws -> Bool {
        guard let service = connection?.remoteObjectProxy as? ResticXPCServiceProtocol else {
            throw ResticXPCError.invalidService
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var isValid = false
        
        service.validateEntitlements(requiredEntitlements) { valid in
            isValid = valid
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + .seconds(5))
        
        return isValid
    }

    // MARK: - Health Check

    public func updateHealthStatus() async {
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
    func performHealthCheck() async throws -> Bool {
        logger.debug("Performing health check",
                     file: #file,
                     function: #function,
                     line: #line)

        // Validate XPC connection
        let isValid = try await securityService.validateXPCConnection(connection)

        // Check if connection is valid (NSXPCConnection doesn't have isValid,
        // but we can check if it's not invalidated)
        if !isValid || connection?.invalidationHandler == nil {
            throw SecurityError.xpcValidationFailed("XPC connection is invalidated")
        }

        return true
    }

    // MARK: - Command Execution

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
            guard let service = connection?.remoteObjectProxy as? ResticXPCProtocol else {
                continuation.resume(
                    throwing: ResticXPCError.serviceUnavailable
                )
                return
            }

            Task {
                do {
                    // Start accessing resources if bookmarks are provided
                    if let bookmarks {
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

    // MARK: - ResticServiceProtocol Implementation

    /// Initializes a new repository at the specified URL.
    /// - Parameter url: The URL where the repository will be initialized.
    /// - Throws: An error if the repository initialization fails.
    func initializeRepository(at url: URL) async throws {
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
    func backup(from source: URL, to destination: URL) async throws {
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
    func listSnapshots() async throws -> [String] {
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
    func restore(from source: URL, to destination: URL) async throws {
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
