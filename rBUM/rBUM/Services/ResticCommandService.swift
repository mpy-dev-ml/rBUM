//
//  ResticCommandService.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation

enum ResticError: LocalizedError {
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
        case .invalidRepository:
            return "The specified path is not a valid Restic repository"
        case .invalidPassword:
            return "Invalid repository password"
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
}

/// Protocol defining the ResticCommandService interface
protocol ResticCommandServiceProtocol {
    func initializeRepository(_ repository: Repository, password: String) async throws
    func checkRepository(_ repository: Repository) async throws -> Bool
    func createBackup(for repository: Repository, paths: [String]) async throws
    func listSnapshots(for repository: Repository) async throws -> [Snapshot]
    func deleteSnapshot(_ snapshotId: String, from repository: Repository) async throws
    func restoreSnapshot(_ snapshotId: String, from repository: Repository, to path: URL) async throws
    func pruneSnapshots(
        for repository: Repository,
        keepLast: Int?,
        keepHourly: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?,
        keepTags: [String]?
    ) async throws
}

/// Service for executing Restic commands
final class ResticCommandService: ResticCommandServiceProtocol {
    private let fileManager = FileManager.default
    private let resticPath: String
    private let credentialsManager: CredentialsManagerProtocol
    private let processExecutor: ProcessExecutorProtocol
    private let logger = Logging.logger(for: .repository)
    private let decoder = JSONDecoder()
    
    init(credentialsManager: CredentialsManagerProtocol, processExecutor: ProcessExecutorProtocol) {
        // TODO: Make this configurable in settings
        self.resticPath = "restic"
        self.credentialsManager = credentialsManager
        self.processExecutor = processExecutor
    }
    
    @discardableResult
    private func executeCommand(_ arguments: [String], password: String? = nil, repository: Repository? = nil) async throws -> String {
        var environment: [String: String] = [:]
        if let password = password {
            environment["RESTIC_PASSWORD"] = password
        }
        if let repository = repository {
            environment["RESTIC_REPOSITORY"] = repository.path.path
        }
        
        let result = try await processExecutor.execute(command: resticPath, arguments: arguments, environment: environment)
        
        if result.exitCode != 0 {
            throw ResticError.commandFailed(result.error)
        }
        
        return result.output
    }
    
    func initializeRepository(_ repository: Repository, password: String) async throws {
        let arguments = ["init"]
        try await executeCommand(arguments, password: password, repository: repository)
        try await credentialsManager.storeCredentials(password, for: repository.credentials)
    }
    
    func checkRepository(_ repository: Repository) async throws -> Bool {
        let password = try await credentialsManager.retrievePassword(for: repository.credentials)
        
        let arguments = ["check"]
        do {
            _ = try await executeCommand(arguments, password: password, repository: repository)
            return true
        } catch ResticError.commandFailed {
            return false
        }
    }
    
    func createBackup(for repository: Repository, paths: [String]) async throws {
        guard !paths.isEmpty else {
            throw ResticError.invalidArgument("No paths specified for backup")
        }
        
        // Validate all paths exist
        for path in paths {
            guard fileManager.fileExists(atPath: path) else {
                throw ResticError.invalidArgument("Path does not exist: \(path)")
            }
        }
        
        var arguments = ["backup"]
        arguments.append(contentsOf: paths)
        
        // Add standard flags
        arguments.append("--json")  // Get JSON output for progress
        arguments.append("--verbose")  // Get detailed output
        
        // Get repository password
        let password = try await credentialsManager.retrievePassword(for: repository.credentials)
        
        // Execute backup command
        try await executeCommand(arguments, password: password, repository: repository)
    }
    
    func listSnapshots(for repository: Repository) async throws -> [Snapshot] {
        let password = try await credentialsManager.retrievePassword(for: repository.credentials)
        
        let arguments = ["snapshots", "--json"]
        
        let output = try await executeCommand(arguments, password: password, repository: repository)
        
        return try decoder.decode([Snapshot].self, from: Data(output.utf8))
    }
    
    func deleteSnapshot(_ snapshotId: String, from repository: Repository) async throws {
        let password = try await credentialsManager.retrievePassword(for: repository.credentials)
        
        let arguments = ["forget", "--prune", snapshotId]
        
        try await executeCommand(arguments, password: password, repository: repository)
    }
    
    func restoreSnapshot(_ snapshotId: String, from repository: Repository, to path: URL) async throws {
        let password = try await credentialsManager.retrievePassword(for: repository.credentials)
        
        let arguments = ["restore", snapshotId, "--target", path.path]
        
        try await executeCommand(arguments, password: password, repository: repository)
    }
    
    func pruneSnapshots(
        for repository: Repository,
        keepLast: Int?,
        keepHourly: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?,
        keepTags: [String]?
    ) async throws {
        var arguments = ["forget", "--prune"]
        
        if let keepLast = keepLast {
            arguments.append("--keep-last")
            arguments.append("\(keepLast)")
        }
        
        if let keepHourly = keepHourly {
            arguments.append("--keep-hourly")
            arguments.append("\(keepHourly)")
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
        
        if let keepTags = keepTags, !keepTags.isEmpty {
            arguments.append("--keep-tag")
            arguments.append(contentsOf: keepTags)
        }
        
        let password = try await credentialsManager.retrievePassword(for: repository.credentials)
        try await executeCommand(arguments, password: password, repository: repository)
    }
}
