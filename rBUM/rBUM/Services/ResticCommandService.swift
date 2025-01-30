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

/// Protocol for interacting with the Restic command-line tool
protocol ResticCommandServiceProtocol {
    /// Initialize a new repository at the given path
    /// - Parameters:
    ///   - path: Path where the repository should be created
    ///   - password: Password to encrypt the repository
    func initializeRepository(at path: URL, password: String) async throws
    
    /// Check if a repository is valid and accessible
    /// - Parameters:
    ///   - path: Path to the repository
    ///   - credentials: Credentials for accessing the repository
    func checkRepository(at path: URL, credentials: RepositoryCredentials) async throws
    
    /// Create a backup of specified paths
    /// - Parameters:
    ///   - paths: Paths to backup
    ///   - repository: Repository to store the backup
    ///   - credentials: Credentials for accessing the repository
    ///   - tags: Optional tags to apply to the backup
    ///   - onProgress: Optional callback for progress updates
    ///   - onStatusChange: Optional callback for status changes
    func createBackup(
        paths: [URL],
        to repository: Repository,
        credentials: RepositoryCredentials,
        tags: [String]?,
        onProgress: ((BackupProgress) -> Void)?,
        onStatusChange: ((BackupStatus) -> Void)?
    ) async throws
    
    /// List snapshots in a repository
    /// - Parameters:
    ///   - repository: Repository to list snapshots from
    ///   - credentials: Credentials for accessing the repository
    /// - Returns: Array of snapshots
    func listSnapshots(
        in repository: Repository,
        credentials: RepositoryCredentials
    ) async throws -> [Snapshot]
    
    /// Prune old snapshots from a repository
    /// - Parameters:
    ///   - repository: Repository to prune
    ///   - credentials: Credentials for accessing the repository
    ///   - keepLast: Number of most recent snapshots to keep
    ///   - keepDaily: Number of daily snapshots to keep
    ///   - keepWeekly: Number of weekly snapshots to keep
    ///   - keepMonthly: Number of monthly snapshots to keep
    ///   - keepYearly: Number of yearly snapshots to keep
    func pruneSnapshots(
        in repository: Repository,
        credentials: RepositoryCredentials,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws
}

/// Service for interacting with the Restic command-line tool
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
    
    func checkRepository(at path: URL, credentials: RepositoryCredentials) async throws {
        let arguments = ["check"]
        try await executeCommand(arguments, credentials: credentials)
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
    
    func listSnapshots(
        in repository: Repository,
        credentials: RepositoryCredentials
    ) async throws -> [Snapshot] {
        let arguments = ["snapshots", "--json"]
        
        let output = try await executeCommand(arguments, credentials: credentials)
        
        return try JSONDecoder().decode([Snapshot].self, from: Data(output.utf8))
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
}
