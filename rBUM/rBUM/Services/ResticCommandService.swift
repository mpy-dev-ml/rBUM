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
    case invalidData(String)
    
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
        case .invalidData(let message):
            return "Invalid data: \(message)"
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
             let (.resticNotFound(lhsMessage), .resticNotFound(rhsMessage)),
             let (.invalidData(lhsMessage), .invalidData(rhsMessage)):
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
final class ResticCommandService: ResticCommandServiceProtocol {
    private let fileManager: FileManager
    private let logger: Logger
    private let resticPath: String
    private let bookmarkService: BookmarkServiceProtocol
    
    init(
        fileManager: FileManager = .default,
        logger: Logger = Logging.logger(for: .restic),
        bookmarkService: BookmarkServiceProtocol = BookmarkService()
    ) {
        self.fileManager = fileManager
        self.logger = logger
        self.bookmarkService = bookmarkService
        
        // Use bundled restic binary
        let bundlePath = Bundle.main.resourcePath!
        self.resticPath = (bundlePath as NSString).appendingPathComponent("restic")
    }
    
    private func accessSecuredPaths<T>(_ paths: [URL], operation: () async throws -> T) async throws -> T {
        var accessedURLs: [URL] = []
        
        // Start accessing all paths
        for url in paths {
            if url.startAccessingSecurityScopedResource() {
                accessedURLs.append(url)
            } else {
                logger.warning("Failed to access security-scoped resource: \(url.path, privacy: .public)")
            }
        }
        
        defer {
            // Stop accessing all paths in reverse order
            for url in accessedURLs.reversed() {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return try await operation()
    }
    
    func initRepository(credentials: RepositoryCredentials) async throws {
        try await accessSecuredPaths([URL(fileURLWithPath: credentials.repositoryPath)]) {
            logger.info("Initializing repository")
            
            // Create repository directory if it doesn't exist
            if !fileManager.fileExists(atPath: credentials.repositoryPath) {
                try fileManager.createDirectory(
                    atPath: credentials.repositoryPath,
                    withIntermediateDirectories: true
                )
            }
            
            // Initialize repository
            _ = try await executeResticCommand(
                ["init"],
                repository: Repository(
                    name: URL(fileURLWithPath: credentials.repositoryPath).lastPathComponent,
                    path: credentials.repositoryPath,
                    credentials: credentials
                )
            )
            
            logger.info("Repository initialized")
        }
    }
    
    func checkRepository(credentials: RepositoryCredentials) async throws {
        try await accessSecuredPaths([URL(fileURLWithPath: credentials.repositoryPath)]) {
            logger.info("Checking repository")
            
            // Check repository
            _ = try await executeResticCommand(
                ["check"],
                repository: Repository(
                    name: URL(fileURLWithPath: credentials.repositoryPath).lastPathComponent,
                    path: credentials.repositoryPath,
                    credentials: credentials
                )
            )
            
            logger.info("Repository check completed")
        }
    }
    
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        return try await accessSecuredPaths([URL(fileURLWithPath: repository.path)]) {
            let arguments = ["snapshots", "--json"]
            let result = try await executeResticCommand(arguments, repository: repository)
            return try JSONDecoder().decode([ResticSnapshot].self, from: Data(result.output.utf8))
        }
    }
    
    func createBackup(paths: [URL], to repository: Repository, tags: [String]? = nil, onProgress: ((ResticBackupProgress) -> Void)?, onStatusChange: ((ResticBackupStatus) -> Void)?) async throws {
        try await accessSecuredPaths(paths + [URL(fileURLWithPath: repository.path)]) {
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
                _ = try await executeResticCommand(
                    arguments,
                    repository: repository,
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
    }
    
    func pruneSnapshots(in repository: Repository, keepLast: Int?, keepDaily: Int?, keepWeekly: Int?, keepMonthly: Int?, keepYearly: Int?) async throws {
        try await accessSecuredPaths([URL(fileURLWithPath: repository.path)]) {
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
            
            _ = try await executeResticCommand(arguments, repository: repository)
        }
    }
    
    private func executeResticCommand(
        _ arguments: [String],
        repository: Repository,
        credentials: RepositoryCredentials? = nil,
        environment: [String: String]? = nil,
        onOutput: ((String) -> Void)? = nil
    ) async throws -> Core.ProcessResult {
        var processEnvironment = ProcessInfo.processInfo.environment
        if let credentials = credentials {
            processEnvironment["RESTIC_PASSWORD"] = credentials.password
        }
        processEnvironment["RESTIC_REPOSITORY"] = repository.path
        
        if let additionalEnv = environment {
            processEnvironment.merge(additionalEnv) { current, _ in current }
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resticPath)
        process.arguments = arguments
        process.environment = processEnvironment
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
            let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
            
            if process.terminationStatus != 0 {
                if let errorMessage = String(data: errorData, encoding: .utf8) {
                    logger.error("Restic command failed: \(errorMessage, privacy: .public)")
                    throw ResticError.commandFailed(errorMessage)
                }
            }
            
            if let onOutput = onOutput,
               let outputString = String(data: outputData, encoding: .utf8) {
                onOutput(outputString)
            }
            
            return Core.ProcessResult(
                exitCode: Int(process.terminationStatus),
                output: String(data: outputData, encoding: .utf8) ?? "",
                error: String(data: errorData, encoding: .utf8) ?? ""
            )
        } catch {
            logger.error("Failed to execute restic command: \(error.localizedDescription, privacy: .public)")
            throw ResticError.commandError(error.localizedDescription)
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
}
