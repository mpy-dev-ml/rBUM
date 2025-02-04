import Foundation
import Core
import AppKit
import os.log

/// Service for executing restic commands via XPC
final class ResticCommandService: ResticCommandServiceProtocol {
    private let logger: LoggerProtocol
    private let fileManager: FileManager
    private let securityService: SecurityServiceProtocol
    private var xpcConnection: NSXPCConnection?
    private let sandboxDiagnostics: SandboxDiagnostics
    
    /// Temporary directory for command execution
    private var workingDirectory: URL {
        fileManager.temporaryDirectory.appendingPathComponent("dev.mpy.rBUM/restic", isDirectory: true)
    }
    
    init(
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "ResticCommand"),
        fileManager: FileManager = .default,
        securityService: SecurityServiceProtocol,
        sandboxDiagnostics: SandboxDiagnostics = SandboxDiagnostics()
    ) {
        self.logger = logger
        self.fileManager = fileManager
        self.securityService = securityService
        self.sandboxDiagnostics = sandboxDiagnostics
        
        setupXPCConnection()
        
        // Create working directory
        try? fileManager.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true
        )
    }
    
    deinit {
        xpcConnection?.invalidate()
    }
    
    // MARK: - ResticCommandServiceProtocol
    
    public func initRepository(credentials: RepositoryCredentials) async throws {
        try await executeResticCommand(.initialize, for: credentials.repository)
    }
    
    public func createBackup(paths: [URL], to repository: Repository, credentials: RepositoryCredentials, tags: [String]?) async throws {
        try await executeResticCommand(.backup, for: repository)
    }
    
    public func listSnapshots(in repository: Repository, credentials: RepositoryCredentials) async throws -> [Snapshot] {
        let result = try await executeResticCommand(.snapshots, for: repository)
        // TODO: Parse snapshots from result
        return []
    }
    
    public func restoreSnapshot(_ snapshot: Snapshot, to path: URL, credentials: RepositoryCredentials) async throws {
        try await executeResticCommand(.restore, for: snapshot.repository)
    }
    
    public func checkRepository(_ repository: Repository, credentials: RepositoryCredentials) async throws {
        try await executeResticCommand(.check, for: repository)
    }
    
    // MARK: - Private Methods
    
    /// Execute a restic command
    /// - Parameters:
    ///   - command: The command to execute
    ///   - repository: The repository to operate on
    /// - Returns: The result of the command execution
    /// - Throws: ResticError if the command fails
    private func executeResticCommand(_ command: ResticCommand, for repository: Repository) async throws -> ProcessResult {
        logger.debug("Executing restic command: \(command.rawValue)")
        
        // Monitor file access
        sandboxDiagnostics.monitorFileAccess(url: URL(fileURLWithPath: repository.path), operation: "read")
        
        // Track resources we need to access
        var accessedResources: [URL] = []
        
        // Ensure we have access to the repository
        let repoURL = URL(fileURLWithPath: repository.path)
        if try await securityService.validateAccess(to: repoURL) {
            accessedResources.append(repoURL)
            logger.debug("Repository access validated")
        }
        
        // Setup XPC service
        guard let service = try await getResticService() else {
            throw ResticError.serviceUnavailable
        }
        
        // Execute command
        do {
            let result = try await service.executeCommand(command.rawValue)
            logger.debug("Command execution completed")
            return result
        } catch {
            logger.error("Command execution failed: \(error.localizedDescription)")
            throw ResticError.commandFailed(error)
        } finally {
            // Stop accessing resources
            for url in accessedResources {
                try? await securityService.stopAccessing(url)
            }
        }
    }
    
    private func setupXPCConnection() {
        xpcConnection = NSXPCConnection(serviceName: "dev.mpy.rBUM.ResticService")
        xpcConnection?.remoteObjectInterface = NSXPCInterface(with: ResticServiceProtocol.self)
        
        // Monitor IPC access
        sandboxDiagnostics.monitorIPCAccess(service: "ResticService")
        
        xpcConnection?.resume()
        logger.debug("XPC connection setup complete")
    }
    
    private func validateWorkingDirectory() throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: workingDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            logger.error("Working directory validation failed")
            throw ResticError.invalidWorkingDirectory
        }
        
        // Check directory attributes
        let attributes = try fileManager.attributesOfItem(atPath: workingDirectory.path)
        guard let creationDate = attributes[.creationDate] as? Date else {
            throw ResticError.invalidWorkingDirectory
        }
        
        // Setup directory enumerator
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        guard let enumerator = fileManager.enumerator(
            at: workingDirectory,
            includingPropertiesForKeys: [.creationDate],
            options: options
        ) else {
            throw ResticError.invalidWorkingDirectory
        }
        
        // Check all files in directory
        for case let fileURL as URL in enumerator {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            guard let fileDate = attributes[.creationDate] as? Date,
                  fileDate >= creationDate else {
                logger.error("Found invalid file in working directory: \(fileURL.lastPathComponent)")
                throw ResticError.invalidWorkingDirectory
            }
        }
    }
    
    private func getResticService() async throws -> ResticServiceProtocol? {
        guard let connection = xpcConnection else {
            throw ResticError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.remoteObjectProxyWithErrorHandler { error in
                self.logger.error("XPC connection failed: \(error.localizedDescription)")
                continuation.resume(throwing: ResticError.serviceUnavailable)
            } as? ResticServiceProtocol
        }
    }
}

/// Represents a restic command with its arguments
private enum ResticCommand: String {
    case initialize = "init"
    case backup = "backup"
    case restore = "restore"
    case snapshots = "snapshots"
    case check = "check"
}

/// Errors that can occur during restic operations
private enum ResticError: Error {
    case serviceUnavailable
    case commandFailed(Error)
    case invalidWorkingDirectory
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Restic service is not available"
        case .commandFailed(let error):
            return "Command failed: \(error.localizedDescription)"
        case .invalidWorkingDirectory:
            return "Invalid working directory"
        }
    }
}
