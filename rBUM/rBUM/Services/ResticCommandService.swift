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

/// Protocol defining the interface for interacting with the restic command-line tool
protocol ResticCommandServiceProtocol {
    /// Initialize a new repository
    func initializeRepository(at path: URL, password: String) async throws
    
    /// List all snapshots in a repository
    func listSnapshots(in repository: ResticRepository) async throws -> [ResticSnapshot]
    
    /// Create a new backup
    func createBackup(paths: [URL], to repository: ResticRepository, tags: [String]?, onProgress: ((ResticBackupProgress) -> Void)?, onStatusChange: ((ResticBackupStatus) -> Void)?) async throws
    
    /// Prune old snapshots from a repository
    func pruneSnapshots(in repository: ResticRepository, keepLast: Int?, keepDaily: Int?, keepWeekly: Int?, keepMonthly: Int?, keepYearly: Int?) async throws
    
    /// Check repository integrity
    func check(_ repository: ResticRepository) async throws
}

/// Restic command execution service
class ResticCommandService: ResticCommandServiceProtocol {
    private let fileManager: FileManager
    private let logger: os.Logger
    private let resticPath: String
    
    init(
        fileManager: FileManager = .default,
        logger: os.Logger = Logging.logger(for: .repository)
    ) {
        self.fileManager = fileManager
        self.logger = logger
        
        // Find restic in PATH or use default location
        if let path = ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":").first(where: { path in
            let resticPath = (path as NSString).appendingPathComponent("restic")
            return fileManager.fileExists(atPath: resticPath)
        }) {
            self.resticPath = (path as NSString).appendingPathComponent("restic")
        } else {
            // Default to /usr/local/bin/restic if not found in PATH
            self.resticPath = "/usr/local/bin/restic"
        }
    }
    
    /// Execute a restic command with the given arguments
    private func executeCommand(
        _ arguments: [String],
        credentials: RepositoryCredentials,
        onOutput: ((String) -> Void)? = nil
    ) async throws -> String {
        var allArguments = arguments
        
        // Add repository path
        allArguments.insert(credentials.repositoryPath, at: 0)
        allArguments.insert("--repo", at: 0)
        
        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resticPath)
        process.arguments = allArguments
        
        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["RESTIC_PASSWORD"] = credentials.password
        process.environment = environment
        
        // Set up pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Start process
        do {
            try process.run()
        } catch {
            throw ResticError.commandError("Failed to start restic: \(error.localizedDescription)")
        }
        
        // Handle output asynchronously
        var output = ""
        for try await line in outputPipe.fileHandleForReading.bytes.lines {
            output += line + "\n"
            onOutput?(line)
        }
        
        // Wait for process to complete
        let status = await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume(returning: process.terminationStatus)
            }
        }
        
        // Check for errors
        if status != 0 {
            let errorOutput = try errorPipe.fileHandleForReading.readToEnd().flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw ResticError.commandError("restic failed with status \(status): \(errorOutput)")
        }
        
        return output
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
    
    func initializeRepository(at path: URL, password: String) async throws {
        let arguments = ["init"]
        
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: password,
            repositoryPath: path.path
        )
        
        try await executeCommand(arguments, credentials: credentials)
    }
    
    func listSnapshots(in repository: ResticRepository) async throws -> [ResticSnapshot] {
        let arguments = ["snapshots", "--json"]
        
        let output = try await executeCommand(arguments, credentials: repository.credentials)
        
        return try JSONDecoder().decode([ResticSnapshot].self, from: Data(output.utf8))
    }
    
    func createBackup(paths: [URL], to repository: ResticRepository, tags: [String]? = nil, onProgress: ((ResticBackupProgress) -> Void)?, onStatusChange: ((ResticBackupStatus) -> Void)?) async throws {
        guard !paths.isEmpty else {
            throw ResticError.invalidArgument("No paths specified for backup")
        }
        
        var arguments = ["backup"]
        
        // Add paths to backup
        arguments.append(contentsOf: paths.map { $0.path })
        
        // Add tags if specified
        if let tags = tags {
            for tag in tags {
                arguments.append(contentsOf: ["--tag", tag])
            }
        }
        
        // Add JSON output flag
        arguments.append("--json")
        
        onStatusChange?(.preparing)
        
        do {
            try await executeCommand(
                arguments,
                credentials: repository.credentials,
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
    
    func pruneSnapshots(in repository: ResticRepository, keepLast: Int?, keepDaily: Int?, keepWeekly: Int?, keepMonthly: Int?, keepYearly: Int?) async throws {
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
        
        try await executeCommand(arguments, credentials: repository.credentials)
    }
    
    func check(_ repository: ResticRepository) async throws {
        let arguments = [
            "check",
            "--json"
        ]
        
        let output = try await executeCommand(arguments, credentials: repository.credentials)
        guard let outputData = output.data(using: String.Encoding.utf8) else {
            throw ResticError.commandError("Invalid output format")
        }
    }
}
