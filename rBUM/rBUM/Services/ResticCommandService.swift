//
//  ResticCommandService.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation
import os
import os.log

/// Errors that can occur during Restic operations
enum ResticError: LocalizedError, Equatable {
    case commandFailed(String)
    case invalidRepository
    case invalidPassword
    case repositoryNotFound
    case backupFailed(String)
    case restoreFailed(String)
    case credentialsNotFound
    case snapshotNotFound(String)
    case restoreError(String)
    case commandError(String)
    case invalidArgument(String)
    case resticNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRepository:
            return "The specified path is not a valid Restic repository"
        case .invalidPassword:
            return "Invalid repository password"
        case .snapshotNotFound(let id):
            return "Snapshot \(id) not found in repository"
        case .restoreError(let message):
            return "Failed to restore snapshot: \(message)"
        case .commandError(let message):
            return "Command failed: \(message)"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .repositoryNotFound:
            return "Repository not found"
        case .backupFailed(let message):
            return "Backup failed: \(message)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        case .credentialsNotFound:
            return "Credentials not found"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .resticNotFound(let message):
            return "Restic not found: \(message). Please ensure restic is installed and accessible."
        }
    }
    
    static func == (lhs: ResticError, rhs: ResticError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidRepository, .invalidRepository),
             (.invalidPassword, .invalidPassword),
             (.repositoryNotFound, .repositoryNotFound),
             (.credentialsNotFound, .credentialsNotFound):
            return true
        case let (.commandFailed(lhsMessage), .commandFailed(rhsMessage)),
             let (.backupFailed(lhsMessage), .backupFailed(rhsMessage)),
             let (.restoreFailed(lhsMessage), .restoreFailed(rhsMessage)),
             let (.snapshotNotFound(lhsMessage), .snapshotNotFound(rhsMessage)),
             let (.restoreError(lhsMessage), .restoreError(rhsMessage)),
             let (.commandError(lhsMessage), .commandError(rhsMessage)),
             let (.invalidArgument(lhsMessage), .invalidArgument(rhsMessage)),
             let (.resticNotFound(lhsMessage), .resticNotFound(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

/// Protocol defining the interface for interacting with the restic command-line tool
protocol ResticCommandServiceProtocol {
    /// Initialize a new repository
    func initRepository(credentials: RepositoryCredentials) async throws
    
    /// Check repository integrity
    func checkRepository(credentials: RepositoryCredentials) async throws
    
    /// List all snapshots in a repository
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot]
    
    /// Create a new backup
    func createBackup(paths: [URL], to repository: Repository, tags: [String]?, onProgress: ((ResticBackupProgress) -> Void)?, onStatusChange: ((ResticBackupStatus) -> Void)?) async throws
    
    /// Prune old snapshots from a repository
    func pruneSnapshots(in repository: Repository, keepLast: Int?, keepDaily: Int?, keepWeekly: Int?, keepMonthly: Int?, keepYearly: Int?) async throws
}

/// Restic command execution service
class ResticCommandService: ResticCommandServiceProtocol {
    private let fileManager: FileManager
    private let logger: os.Logger
    private let resticPath: String
    
    init(
        fileManager: FileManager = .default,
        logger: os.Logger = Logging.logger(for: .restic)
    ) {
        self.fileManager = fileManager
        self.logger = logger
        
        // Use command name and let shell resolve it
        self.resticPath = "restic"
        
        // Log the command being used
        self.logger.debug("Using restic command")
    }
    
    /// Initialize a new repository
    func initRepository(credentials: RepositoryCredentials) async throws {
        logger.info("Initializing repository")
        
        // Create repository directory if it doesn't exist
        if !fileManager.fileExists(atPath: credentials.repositoryPath) {
            try fileManager.createDirectory(
                atPath: credentials.repositoryPath,
                withIntermediateDirectories: true
            )
        }
        
        // Initialize repository
        _ = try await executeCommand(
            ["init"],
            credentials: credentials
        )
        
        logger.info("Repository initialized")
    }
    
    /// Check repository integrity
    func checkRepository(credentials: RepositoryCredentials) async throws {
        logger.info("Checking repository")
        
        // Check repository
        _ = try await executeCommand(
            ["check"],
            credentials: credentials
        )
        
        logger.info("Repository check completed")
    }
    
    /// Execute a restic command with the given arguments
    private func executeCommand(
        _ arguments: [String],
        credentials: RepositoryCredentials,
        onOutput: ((String) -> Void)? = nil
    ) async throws -> ProcessResult {
        // Set up environment with repository password and PATH
        var environment = ProcessInfo.processInfo.environment
        environment["RESTIC_PASSWORD"] = credentials.password
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        
        // Build full arguments with repository path
        var fullArguments = ["--repo", credentials.repositoryPath]
        fullArguments.append(contentsOf: arguments)
        
        // Log command details (excluding password)
        logger.debug("""
            Executing restic command:
            Arguments: \(fullArguments)
            Repository: \(credentials.repositoryPath)
            PATH: \(environment["PATH"] ?? "not set")
            """)
        
        // Execute command
        let executor = ProcessExecutor()
        do {
            let result = try await executor.execute(
                command: resticPath,
                arguments: fullArguments,
                environment: environment,
                onOutput: onOutput
            )
            
            // Check for errors
            if result.exitCode != 0 {
                logger.error("Command failed with exit code \(result.exitCode)")
                logger.error("Error output: \(result.error)")
                throw ResticError.commandFailed(result.error.isEmpty ? result.output : result.error)
            }
            
            return result
        } catch ProcessError.commandNotFound {
            logger.error("Shell could not find restic command")
            throw ResticError.resticNotFound("""
                Could not find restic command in PATH.
                Please ensure:
                1. Restic is installed: brew install restic
                2. Your shell can find it: which restic
                3. The PATH includes: /opt/homebrew/bin
                """)
        } catch ProcessError.executionFailed(let message) {
            logger.error("Process execution failed: \(message)")
            throw ResticError.commandFailed("Failed to execute restic: \(message)")
        } catch {
            logger.error("Unknown error: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func parseBackupProgress(_ line: String) -> ResticBackupProgress? {
        guard let data = line.data(using: .utf8) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(ResticBackupResponse.self, from: data)
            
            // Only process "status" messages
            guard response.messageType == "status" else { return nil }
            
            return response.toBackupProgress(startTime: Date())
        } catch {
            self.logger.debug("Failed to parse backup progress: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func parseBackupStatus(_ line: String) -> ResticBackupStatus? {
        guard let data = line.data(using: .utf8) else { return nil }
        
        do {
            return try JSONDecoder().decode(ResticBackupStatus.self, from: data)
        } catch {
            self.logger.debug("Failed to parse backup status: \(error.localizedDescription)")
            return nil
        }
    }
    
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        guard let credentials = repository.credentials else {
            throw RepositoryError.credentialsNotFound
        }
        
        let arguments = ["snapshots", "--json"]
        let output = try await executeCommand(arguments, credentials: credentials)
        return try JSONDecoder().decode([ResticSnapshot].self, from: Data(output.output.utf8))
    }
    
    func createBackup(paths: [URL], to repository: Repository, tags: [String]? = nil, onProgress: ((ResticBackupProgress) -> Void)?, onStatusChange: ((ResticBackupStatus) -> Void)?) async throws {
        guard let credentials = repository.credentials else {
            throw RepositoryError.credentialsNotFound
        }
        
        guard !paths.isEmpty else {
            throw ResticError.invalidArgument("No paths specified for backup")
        }
        
        var arguments = ["backup"]
        arguments.append(contentsOf: paths.map { $0.path })
        
        if let tags = tags {
            for tag in tags {
                arguments.append(contentsOf: ["--tag", tag])
            }
        }
        
        arguments.append("--json")
        onStatusChange?(.preparing)
        
        do {
            _ = try await executeCommand(
                arguments,
                credentials: credentials,
                onOutput: { line in
                    if let progress = self.parseBackupProgress(line) {
                        onProgress?(progress)
                        onStatusChange?(.backing(progress))
                    } else if let status = self.parseBackupStatus(line) {
                        onStatusChange?(status)
                    }
                }
            )
            onStatusChange?(.completed)
        } catch {
            if let resticError = error as? ResticError {
                onStatusChange?(.failed(ResticBackupError(
                    type: .operationInterrupted,
                    message: resticError.localizedDescription,
                    details: "Restic command failed during backup operation"
                )))
            } else {
                onStatusChange?(.failed(ResticBackupError(
                    type: .unclassifiedError,
                    message: error.localizedDescription
                )))
            }
            throw error
        }
    }
    
    func pruneSnapshots(in repository: Repository, keepLast: Int?, keepDaily: Int?, keepWeekly: Int?, keepMonthly: Int?, keepYearly: Int?) async throws {
        guard let credentials = repository.credentials else {
            throw RepositoryError.credentialsNotFound
        }
        
        var arguments = ["forget", "--prune"]
        
        if let keepLast = keepLast {
            arguments.append("--keep-last")
            arguments.append(String(keepLast))
        }
        
        if let keepDaily = keepDaily {
            arguments.append("--keep-daily")
            arguments.append(String(keepDaily))
        }
        
        if let keepWeekly = keepWeekly {
            arguments.append("--keep-weekly")
            arguments.append(String(keepWeekly))
        }
        
        if let keepMonthly = keepMonthly {
            arguments.append("--keep-monthly")
            arguments.append(String(keepMonthly))
        }
        
        if let keepYearly = keepYearly {
            arguments.append("--keep-yearly")
            arguments.append(String(keepYearly))
        }
        
        _ = try await executeCommand(arguments, credentials: credentials)
    }
    
    func check(_ repository: Repository) async throws {
        guard let credentials = repository.credentials else {
            throw RepositoryError.credentialsNotFound
        }
        
        let arguments = ["check", "--json"]
        let output = try await executeCommand(arguments, credentials: credentials)
        
        if output.output.data(using: .utf8) == nil {
            throw ResticError.commandError("Invalid output format")
        }
    }
}
