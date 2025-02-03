//
//  RestoreService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Service for restoring files from backups
final class RestoreService: RestoreServiceProtocol {
    // MARK: - Private Properties
    
    private let fileManager: FileManagerProtocol
    private let logger: LoggerProtocol
    private let securityService: SecurityServiceProtocol
    private let repositoryService: RepositoryServiceProtocol
    private let dateProvider: DateProviderProtocol
    private let notificationCenter: NotificationCenterProtocol
    
    // MARK: - Initialization
    
    init(
        fileManager: FileManagerProtocol = FileManager.default,
        logger: LoggerProtocol = Logging.logger(for: .restore),
        securityService: SecurityServiceProtocol = SecurityService(),
        repositoryService: RepositoryServiceProtocol = ResticCommandService(),
        dateProvider: DateProviderProtocol = DateProvider(),
        notificationCenter: NotificationCenterProtocol = NotificationCenter.default
    ) {
        self.fileManager = fileManager
        self.logger = logger
        self.securityService = securityService
        self.repositoryService = repositoryService
        self.dateProvider = dateProvider
        self.notificationCenter = notificationCenter
        
        logger.debug("Initialized RestoreService", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    // MARK: - RestoreServiceProtocol Implementation
    
    func restore(
        from snapshot: ResticSnapshot,
        paths: [String]?,
        to targetDirectory: URL,
        repository: Repository,
        credentials: RepositoryCredentials,
        onProgress: ((RestoreProgress) -> Void)?,
        onStatusChange: ((RestoreStatus) -> Void)?
    ) async throws {
        logger.info("Starting restore from snapshot: \(snapshot.id)", privacy: .public, file: #file, function: #function, line: #line)
        logger.debug("Target directory: \(targetDirectory.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        onStatusChange?(.preparing)
        
        do {
            // Validate target directory access
            try securityService.validateAccess(to: targetDirectory)
            
            // Create target directory if needed
            if !fileManager.fileExists(atPath: targetDirectory.path) {
                try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            }
            
            // Create progress tracker
            let tracker = ProgressTracker(total: Int64(snapshot.stats.totalFiles))
            
            // Perform restore
            onStatusChange?(.restoring)
            
            try await repositoryService.restoreSnapshot(
                snapshot,
                to: targetDirectory,
                from: repository,
                credentials: credentials
            ) { progress in
                tracker.update(processed: Int64(progress))
                onProgress?(RestoreProgress(
                    processedFiles: progress,
                    totalFiles: snapshot.stats.totalFiles,
                    startTime: dateProvider.now
                ))
            }
            
            // Complete restore
            tracker.complete()
            onStatusChange?(.completed)
            
            // Post notification
            notificationCenter.post(
                name: .restoreCompleted,
                object: self,
                userInfo: [
                    "snapshotId": snapshot.id,
                    "repository": repository.id
                ]
            )
            
            logger.info("Successfully restored snapshot: \(snapshot.id)", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            onStatusChange?(.failed(error))
            throw error
        }
    }
    
    func listFiles(
        in snapshot: ResticSnapshot,
        repository: Repository,
        credentials: RepositoryCredentials
    ) async throws -> [String] {
        logger.info("Listing files in snapshot: \(snapshot.id)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // List files using repository service
            let files = try await repositoryService.listFiles(
                in: snapshot,
                repository: repository,
                credentials: credentials
            )
            
            logger.info("Found \(files.count) files in snapshot", privacy: .public, file: #file, function: #function, line: #line)
            return files
        } catch {
            logger.error("Failed to list files: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
}

// MARK: - Restore Errors

/// Errors that can occur during restore operations
enum RestoreError: LocalizedError {
    case accessDenied(String)
    case snapshotNotFound
    case invalidSnapshot
    case fileSystemError(String)
    case operationFailed(String)
    case bookmarkInvalid(String)
    case bookmarkStale(String)
    case restoreFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied(let path):
            return "Access denied to \(path)"
        case .snapshotNotFound:
            return "Snapshot not found"
        case .invalidSnapshot:
            return "Invalid snapshot"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .bookmarkInvalid(let path):
            return "Invalid bookmark for \(path)"
        case .bookmarkStale(let path):
            return "Stale bookmark for \(path)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        }
    }
}
