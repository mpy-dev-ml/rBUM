//
//  ResticCommandService.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation

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
             let (.invalidArgument(lhsMessage), .invalidArgument(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

/// Handles Restic command execution and error handling
protocol ResticCommandServiceProtocol {
    /// Initialize a new repository
    func initializeRepository(at path: URL, password: String) async throws
    
    /// List all snapshots in a repository
    func listSnapshots(in repository: Repository, credentials: RepositoryCredentials) async throws -> [Snapshot]
    
    /// Create a new backup
    func createBackup(paths: [URL], to repository: Repository, credentials: RepositoryCredentials, tags: [String]?, onProgress: ((BackupProgress) -> Void)?, onStatusChange: ((BackupStatus) -> Void)?) async throws
    
    /// Prune old snapshots from a repository
    func pruneSnapshots(in repository: Repository, credentials: RepositoryCredentials, keepLast: Int?, keepDaily: Int?, keepWeekly: Int?, keepMonthly: Int?, keepYearly: Int?) async throws
    
    /// Check repository integrity and return its status
    func checkRepository(_ repository: URL, withPassword password: String) async throws -> RepositoryStatus
}

/// Restic command execution service
final class ResticCommandService: ResticCommandServiceProtocol {
    private let fileManager = FileManager.default
    private let resticPath: String
    private let credentialsManager: CredentialsManagerProtocol
    private let processExecutor: ProcessExecutorProtocol
    private let logger = Logging.logger(for: .repository)
    
    init(
        resticPath: String = "/opt/homebrew/bin/restic",
        credentialsManager: CredentialsManagerProtocol,
        processExecutor: ProcessExecutorProtocol
    ) {
        self.resticPath = resticPath
        self.credentialsManager = credentialsManager
        self.processExecutor = processExecutor
    }
    
    @discardableResult
    private func executeCommand(
        _ arguments: [String],
        credentials: RepositoryCredentials,
        onOutput: ((String) -> Void)? = nil
    ) async throws -> String {
        var environment: [String: String] = [:]
        
        // Set password and repository path from credentials
        environment["RESTIC_PASSWORD"] = credentials.password
        environment["RESTIC_REPOSITORY"] = credentials.repositoryPath
        
        let result = try await processExecutor.execute(
            command: resticPath,
            arguments: arguments,
            environment: environment,
            onOutput: onOutput
        )
        
        if result.exitCode != 0 {
            throw ResticError.commandFailed(result.error)
        }
        
        return result.output
    }
    
    private func parseBackupOutput(
        _ line: String,
        startTime: Date,
        onProgress: ((BackupProgress) -> Void)?,
        onStatusChange: ((BackupStatus) -> Void)?
    ) {
        guard let data = line.data(using: .utf8) else { return }
        
        do {
            let status = try JSONDecoder().decode(ResticBackupStatus.self, from: data)
            
            // Handle different message types
            switch status.messageType {
            case "status":
                if let progress = status.toBackupProgress(startTime: startTime) {
                    onProgress?(progress)
                    onStatusChange?(.backing(progress))
                }
            case "summary":
                onStatusChange?(.finalising)
            default:
                break
            }
        } catch {
            // Not all lines will be valid JSON status updates, ignore those
            logger.debugMessage("Failed to parse backup status: \(error.localizedDescription)")
        }
    }
    
    func initializeRepository(at path: URL, password: String) async throws {
        let arguments = ["init"]
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: password,
            repositoryPath: path.path
        )
        try await executeCommand(arguments, credentials: credentials)
    }
    
    func listSnapshots(
        in repository: Repository,
        credentials: RepositoryCredentials
    ) async throws -> [Snapshot] {
        let arguments = ["snapshots", "--json"]
        
        let output = try await executeCommand(arguments, credentials: credentials)
        
        return try JSONDecoder().decode([Snapshot].self, from: Data(output.utf8))
    }
    
    func createBackup(
        paths: [URL],
        to repository: Repository,
        credentials: RepositoryCredentials,
        tags: [String]?,
        onProgress: ((BackupProgress) -> Void)?,
        onStatusChange: ((BackupStatus) -> Void)?
    ) async throws {
        guard !paths.isEmpty else {
            throw ResticError.invalidArgument("No paths specified for backup")
        }
        
        // Validate all paths exist
        for path in paths {
            guard fileManager.fileExists(atPath: path.path) else {
                throw ResticError.invalidArgument("Path does not exist: \(path.path)")
            }
        }
        
        var arguments = ["backup"]
        arguments.append(contentsOf: paths.map { $0.path })
        
        // Add standard flags
        arguments.append("--json")  // Get JSON output for progress
        arguments.append("--verbose")  // Get detailed output
        
        // Add tags if specified
        if let tags = tags {
            for tag in tags {
                arguments.append("--tag")
                arguments.append(tag)
            }
        }
        
        // Track start time for progress calculation
        let startTime = Date()
        onStatusChange?(.preparing)
        
        do {
            try await executeCommand(
                arguments,
                credentials: credentials,
                onOutput: { line in
                    self.parseBackupOutput(
                        line,
                        startTime: startTime,
                        onProgress: onProgress,
                        onStatusChange: onStatusChange
                    )
                }
            )
            onStatusChange?(.completed)
        } catch {
            onStatusChange?(.failed(error))
            throw error
        }
    }
    
    func pruneSnapshots(
        in repository: Repository,
        credentials: RepositoryCredentials,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {
        var arguments = ["forget", "--prune"]
        
        if let keepLast = keepLast {
            arguments.append("--keep-last")
            arguments.append("\(keepLast)")
        }
        
        if let keepDaily = keepDaily {
            arguments.append("--keep-daily")
            arguments.append("\(keepDaily)")
        }
        
        if let keepWeekly = keepWeekly {
            arguments.append("--keep-weekly")
            arguments.append("\(keepWeekly)")
        }
        
        if let keepMonthly = keepMonthly {
            arguments.append("--keep-monthly")
            arguments.append("\(keepMonthly)")
        }
        
        if let keepYearly = keepYearly {
            arguments.append("--keep-yearly")
            arguments.append("\(keepYearly)")
        }
        
        try await executeCommand(arguments, credentials: credentials)
    }
    
    /// Check repository integrity and return its status
    /// - Parameters:
    ///   - repository: URL of the repository to check
    ///   - password: Repository password
    /// - Returns: Repository status including integrity check results
    func checkRepository(_ repository: URL, withPassword password: String) async throws -> RepositoryStatus {
        let arguments = [
            "check",
            "--json",
            "--repository", repository.path,
            "--password", password
        ]
        
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),  // Generate new UUID since this is a one-time check
            password: password,
            repositoryPath: repository.path
        )
        
        let output = try await executeCommand(arguments, credentials: credentials)
        guard let outputData = output.data(using: String.Encoding.utf8) else {
            throw ResticError.commandError("Invalid output format")
        }
        
        let decoder = JSONDecoder()
        do {
            let status = try decoder.decode(RepositoryStatus.self, from: outputData)
            return status
        } catch {
            throw ResticError.commandError("Failed to parse repository status: \(error.localizedDescription)")
        }
    }
}
