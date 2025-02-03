//
//  ResticCommandService.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation
import Core

/// Service for executing Restic commands
final class ResticCommandService: RepositoryServiceProtocol {
    // MARK: - Private Properties
    
    private let fileManager: FileManagerProtocol
    private let logger: LoggerProtocol
    private let securityService: SecurityServiceProtocol
    private let processExecutor: ProcessExecutorProtocol
    private let dateProvider: DateProviderProtocol
    private let workingDirectory: URL
    private let resticPath: String
    
    // MARK: - Initialization
    
    init(
        fileManager: FileManagerProtocol = FileManager.default,
        logger: LoggerProtocol = Logging.logger(for: .restic),
        securityService: SecurityServiceProtocol = SecurityService(),
        processExecutor: ProcessExecutorProtocol = ProcessExecutor(),
        dateProvider: DateProviderProtocol = DateProvider(),
        workingDirectory: URL = FileManager.default.temporaryDirectory,
        resticPath: String = "/usr/local/bin/restic"
    ) {
        self.fileManager = fileManager
        self.logger = logger
        self.securityService = securityService
        self.processExecutor = processExecutor
        self.dateProvider = dateProvider
        self.workingDirectory = workingDirectory
        self.resticPath = resticPath
        
        logger.debug("Initialized ResticCommandService with restic at: \(resticPath)", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    // MARK: - RepositoryServiceProtocol Implementation
    
    func createRepository(_ repository: Repository, credentials: RepositoryCredentials) async throws {
        logger.info("Creating repository at: \(repository.url.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        try await executeCommand(
            arguments: ["init"],
            repository: repository,
            credentials: credentials
        )
        
        logger.info("Successfully created repository", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    func checkRepository(_ repository: Repository, credentials: RepositoryCredentials) async throws -> RepositoryStatus {
        logger.info("Checking repository: \(repository.url.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        let result = try await executeCommand(
            arguments: ["check", "--json"],
            repository: repository,
            credentials: credentials
        )
        
        // Parse repository status from JSON output
        let status = try JSONDecoder().decode(RepositoryStatus.self, from: Data(result.standardOutput.utf8))
        
        logger.info("Repository check completed", privacy: .public, file: #file, function: #function, line: #line)
        return status
    }
    
    func listSnapshots(_ repository: Repository, credentials: RepositoryCredentials) async throws -> [ResticSnapshot] {
        logger.debug("Listing snapshots in repository: \(repository.url.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        let result = try await executeCommand(
            arguments: ["snapshots", "--json"],
            repository: repository,
            credentials: credentials
        )
        
        // Parse snapshots from JSON output
        let snapshots = try JSONDecoder().decode([ResticSnapshot].self, from: Data(result.standardOutput.utf8))
        
        logger.info("Found \(snapshots.count) snapshots", privacy: .public, file: #file, function: #function, line: #line)
        return snapshots
    }
    
    func deleteSnapshot(_ snapshot: ResticSnapshot, from repository: Repository, credentials: RepositoryCredentials) async throws {
        logger.info("Deleting snapshot \(snapshot.id) from repository: \(repository.url.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        try await executeCommand(
            arguments: ["forget", "--prune", snapshot.id],
            repository: repository,
            credentials: credentials
        )
        
        logger.info("Successfully deleted snapshot", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    func restoreSnapshot(
        _ snapshot: ResticSnapshot,
        to path: URL,
        from repository: Repository,
        credentials: RepositoryCredentials,
        onProgress: ((Int) -> Void)?
    ) async throws {
        logger.info("Restoring snapshot \(snapshot.id) to: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        try await executeCommand(
            arguments: ["restore", snapshot.id, "--target", path.path],
            repository: repository,
            credentials: credentials,
            outputHandler: { line in
                // Parse progress from output line
                if let progress = parseProgress(from: line) {
                    onProgress?(progress)
                }
            }
        )
        
        logger.info("Successfully restored snapshot", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    // MARK: - Private Methods
    
    private func executeCommand(
        arguments: [String],
        repository: Repository,
        credentials: RepositoryCredentials,
        outputHandler: ((String) -> Void)? = nil
    ) async throws -> ProcessResult {
        // Validate repository access
        try securityService.validateAccess(to: repository.url)
        
        // Build command arguments
        var fullArguments = arguments
        fullArguments.append(contentsOf: ["--repo", repository.url.path])
        
        // Set up environment
        let environment = [
            "RESTIC_PASSWORD": credentials.password,
            "PATH": "/usr/local/bin:/usr/bin:/bin"
        ]
        
        // Execute command
        if let outputHandler = outputHandler {
            let exitCode = try await processExecutor.executeWithOutput(
                resticPath,
                arguments: fullArguments,
                environment: environment,
                currentDirectoryPath: workingDirectory.path,
                outputHandler: outputHandler,
                errorHandler: { [weak self] error in
                    self?.logger.error(error, privacy: .public, file: #file, function: #function, line: #line)
                }
            )
            
            guard exitCode == 0 else {
                throw ResticError.commandError("Command failed with exit code: \(exitCode)")
            }
            
            return ProcessResult(exitCode: exitCode, standardOutput: "", standardError: "")
        } else {
            let result = try await processExecutor.execute(
                resticPath,
                arguments: fullArguments,
                environment: environment,
                currentDirectoryPath: workingDirectory.path
            )
            
            guard result.exitCode == 0 else {
                throw ResticError.commandError(result.standardError)
            }
            
            return result
        }
    }
    
    private func parseProgress(from line: String) -> Int? {
        // Example line: "processed 42 files"
        let components = line.components(separatedBy: " ")
        guard components.count >= 2,
              components[0] == "processed",
              let count = Int(components[1]) else {
            return nil
        }
        return count
    }
}

/// Structure representing a file or directory in a Restic repository
private struct ResticNode: Codable {
    let name: String
    let type: String
    let path: String
    let uid: Int
    let gid: Int
    let size: Int64
    let mode: Int
    let mtime: String
    let atime: String
    let ctime: String
}

/// Errors that can occur during Restic operations
enum ResticError: LocalizedError, Equatable {
    case commandError(String)
    case invalidRepository
    case invalidPassword
    case repositoryNotFound
    case backupFailed(String)
    case restoreFailed(String)
    case credentialsNotFound
    case snapshotNotFound(String)
    case restoreError(String)
    case invalidArgument(String)
    case accessDenied(String)
    case bookmarkInvalid(String)
    case bookmarkStale(String)
    case outputParsingFailed
    
    var errorDescription: String? {
        switch self {
        case .commandError(let message):
            return "Command error: \(message)"
        case .invalidRepository:
            return "Invalid repository path"
        case .invalidPassword:
            return "Invalid repository password"
        case .repositoryNotFound:
            return "Repository not found"
        case .backupFailed(let message):
            return "Backup failed: \(message)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        case .credentialsNotFound:
            return "Repository credentials not found"
        case .snapshotNotFound(let id):
            return "Snapshot not found: \(id)"
        case .restoreError(let message):
            return "Restore error: \(message)"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .accessDenied(let message):
            return "Access denied: \(message)"
        case .bookmarkInvalid(let path):
            return "Invalid bookmark for \(path)"
        case .bookmarkStale(let path):
            return "Stale bookmark for \(path)"
        case .outputParsingFailed:
            return "Failed to parse output"
        }
    }
}
