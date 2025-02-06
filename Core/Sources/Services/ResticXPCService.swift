//
//  ResticXPCService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation
import Security

/// Service for managing Restic operations through XPC
public final class ResticXPCService: BaseSandboxedService, Measurable, ResticServiceProtocol {
    // MARK: - Properties
    private let connection: NSXPCConnection
    private let queue: DispatchQueue
    public private(set) var isHealthy: Bool
    private var activeBookmarks: [String: NSData] = [:]
    private let defaultTimeout: TimeInterval = 30.0
    private let maxRetries = 3
    private let interfaceVersion = 1
    
    // MARK: - Initialization
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
    
    // MARK: - Public Methods
    public func executeCommand(_ command: String,
                             arguments: [String],
                             environment: [String: String],
                             workingDirectory: String,
                             bookmarks: [String: NSData]? = nil,
                             retryCount: Int = 0) async throws -> ProcessResult {
        do {
            return try await executeCommandWithTimeout(command,
                                                    arguments: arguments,
                                                    environment: environment,
                                                    workingDirectory: workingDirectory,
                                                    bookmarks: bookmarks,
                                                    timeout: defaultTimeout)
        } catch {
            if retryCount < maxRetries {
                logger.warning("Command execution failed, retrying (\(retryCount + 1)/\(maxRetries))",
                             file: #file,
                             function: #function,
                             line: #line)
                return try await executeCommand(command,
                                             arguments: arguments,
                                             environment: environment,
                                             workingDirectory: workingDirectory,
                                             bookmarks: bookmarks,
                                             retryCount: retryCount + 1)
            }
            throw error
        }
    }
    
    private func executeCommandWithTimeout(_ command: String,
                                        arguments: [String],
                                        environment: [String: String],
                                        workingDirectory: String,
                                        bookmarks: [String: NSData]?,
                                        timeout: TimeInterval) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            guard let service = connection.remoteObjectProxy as? ResticXPCProtocol else {
                continuation.resume(throwing: ResticXPCError.serviceUnavailable)
                return
            }
            
            // Start accessing security-scoped resources
            if let bookmarks = bookmarks {
                do {
                    try startAccessingResources(bookmarks)
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
            }
            
            // Set up timeout
            let timeoutWork = DispatchWorkItem {
                self.stopAccessingResources()
                continuation.resume(throwing: ResticXPCError.timeout)
            }
            
            queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
            
            service.executeCommand(command,
                                arguments: arguments,
                                environment: environment,
                                workingDirectory: workingDirectory,
                                bookmarks: bookmarks ?? [:],
                                timeout: timeout,
                                auditSessionId: ProcessInfo.processInfo.processIdentifier) { [weak self] result in
                timeoutWork.cancel()
                
                // Stop accessing security-scoped resources
                self?.stopAccessingResources()
                
                if let resultDict = result {
                    // Extract values from dictionary
                    guard let exitCode = resultDict["exitCode"] as? Int32,
                          let output = resultDict["output"] as? String,
                          let error = resultDict["error"] as? String else {
                        continuation.resume(throwing: ResticXPCError.executionFailed("Invalid result format"))
                        return
                    }
                    
                    let processResult = ProcessResult(output: output,
                                                    error: error,
                                                    exitCode: Int(exitCode))
                    continuation.resume(returning: processResult)
                } else {
                    continuation.resume(throwing: ResticXPCError.executionFailed("No result received"))
                }
            }
        }
    }
    
    // MARK: - Resource Management
    private func startAccessingResources(_ bookmarks: [String: NSData]) throws {
        for (path, bookmark) in bookmarks {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark as Data,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) else {
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
    
    private func stopAccessingResources() {
        for (path, bookmark) in activeBookmarks {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark as Data,
                                options: .withSecurityScope,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale) {
                url.stopAccessingSecurityScopedResource()
            } else {
                logger.error("Failed to stop accessing resource: \(path)",
                           file: #file,
                           function: #function,
                           line: #line)
            }
        }
        activeBookmarks.removeAll()
    }
    
    private func cleanupResources() {
        stopAccessingResources()
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async throws -> Bool {
        logger.debug("Performing health check", file: #file, function: #function, line: #line)
        
        // Validate XPC connection
        try await securityService.validateXPCConnection(connection)
        
        // Check if connection is valid (NSXPCConnection doesn't have isValid, 
        // but we can check if it's not invalidated)
        if connection.invalidationHandler == nil {
            throw SecurityError.xpcValidationFailed("XPC connection is invalidated")
        }
        
        return true
    }
    
    // MARK: - ResticServiceProtocol Implementation
    public func initializeRepository(at url: URL) async throws {
        logger.info("Initializing repository at \(url.path)", file: #file, function: #function, line: #line)
        
        // Initialize repository
        _ = try await executeCommand("init",
                                arguments: [],
                                environment: [:],
                                workingDirectory: url.path,
                                bookmarks: nil,
                                retryCount: 3)
    }
    
    public func backup(from source: URL, to destination: URL) async throws {
        logger.info("Backing up \(source.path) to \(destination.path)", 
                   file: #file, 
                   function: #function, 
                   line: #line)
        
        let result = try await executeCommand("backup",
                                         arguments: [source.path],
                                         environment: [:],
                                         workingDirectory: destination.path,
                                         bookmarks: nil,
                                         retryCount: 3)
        
        if !result.succeeded {
            throw ProcessError.executionFailed("Backup command failed with exit code: \(result.exitCode)")
        }
    }
    
    public func listSnapshots() async throws -> [String] {
        let result = try await executeCommand("restic",
                                            arguments: ["snapshots", "--json"],
                                            environment: [:],
                                            workingDirectory: "/",
                                            bookmarks: nil)
        // Parse JSON output to extract snapshot IDs
        // This is a simplified implementation
        return result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
    
    public func restore(from source: URL, to destination: URL) async throws {
        logger.info("Restoring from \(source.path) to \(destination.path)", 
                   file: #file, 
                   function: #function, 
                   line: #line)
        
        let result = try await executeCommand("restore",
                                         arguments: ["latest", "--target", destination.path],
                                         environment: [:],
                                         workingDirectory: source.path,
                                         bookmarks: nil,
                                         retryCount: 3)
        
        if !result.succeeded {
            throw ProcessError.executionFailed("Restore command failed with exit code: \(result.exitCode)")
        }
    }
    
    // MARK: - Private Methods
    private func configureConnection() {
        // Set up error handling
        connection.interruptionHandler = { [weak self] in
            self?.handleError(ResticXPCError.serviceUnavailable)
        }
        
        connection.invalidationHandler = { [weak self] in
            self?.handleError(ResticXPCError.connectionFailed)
        }
    }
    
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
    
    private func handleError(_ error: Error) {
        isHealthy = false
        logger.error("XPC service error: \(error.localizedDescription)",
                    file: #file,
                    function: #function,
                    line: #line)
        // Implement recovery strategy based on error type
        if case ResticXPCError.interfaceVersionMismatch = error {
            // Handle version mismatch
            connection.invalidate()
        }
    }
    
    private func handleInvalidation() {
        logger.error("XPC connection invalidated",
                    file: #file,
                    function: #function,
                    line: #line)
        cleanupResources()
        isHealthy = false
    }
    
    private func handleInterruption() {
        logger.error("XPC connection interrupted",
                    file: #file,
                    function: #function,
                    line: #line)
        cleanupResources()
        isHealthy = false
    }
}
