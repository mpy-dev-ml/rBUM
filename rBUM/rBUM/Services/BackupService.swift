//
//  BackupService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Protocol defining backup service operations
protocol BackupServiceProtocol {
    /// Create a new backup repository
    /// - Parameters:
    ///   - path: Path to create repository at
    ///   - password: Password for the repository
    /// - Returns: Created repository
    /// - Throws: BackupError if creation fails
    func createRepository(at path: URL, password: String) async throws -> Repository
    
    /// Initialize an existing backup repository
    /// - Parameters:
    ///   - path: Path to existing repository
    ///   - password: Password for the repository
    /// - Returns: Initialized repository
    /// - Throws: BackupError if initialization fails
    func initializeRepository(at path: URL, password: String) async throws -> Repository
    
    /// Delete a backup repository
    /// - Parameter repository: Repository to delete
    /// - Throws: BackupError if deletion fails
    func deleteRepository(_ repository: Repository) async throws
    
    /// List snapshots in a repository
    /// - Parameter repository: Repository to list snapshots from
    /// - Returns: Array of snapshots
    /// - Throws: BackupError if listing fails
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot]
}

/// Service responsible for managing backup operations
final class BackupService: BackupServiceProtocol {
    // MARK: - Private Properties
    
    private let fileManager: FileManagerProtocol
    private let logger: LoggerProtocol
    private let securityService: SecurityServiceProtocol
    private let bookmarkService: BookmarkServiceProtocol
    private let processExecutor: ProcessExecutorProtocol
    private let dateProvider: DateProviderProtocol
    private let notificationCenter: NotificationCenterProtocol
    private let workingDirectory: URL
    
    // MARK: - Initialization
    
    init(
        fileManager: FileManagerProtocol = FileManager.default,
        logger: LoggerProtocol = Logging.logger(for: .backup),
        securityService: SecurityServiceProtocol = SecurityService(),
        bookmarkService: BookmarkServiceProtocol = BookmarkService(),
        processExecutor: ProcessExecutorProtocol = ProcessExecutor(),
        dateProvider: DateProviderProtocol = DateProvider(),
        notificationCenter: NotificationCenterProtocol = NotificationCenter.default,
        workingDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.fileManager = fileManager
        self.logger = logger
        self.securityService = securityService
        self.bookmarkService = bookmarkService
        self.processExecutor = processExecutor
        self.dateProvider = dateProvider
        self.notificationCenter = notificationCenter
        self.workingDirectory = workingDirectory
        
        logger.debug("Initialized BackupService with working directory: \(workingDirectory.path)", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    // MARK: - Public Methods
    
    func createRepository(at path: URL, password: String) async throws -> Repository {
        logger.info("Creating new repository at: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Validate path access
            logger.debug("Validating access to path: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
            guard try bookmarkService.validateBookmark(for: path) else {
                logger.error("Cannot access repository location: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
                throw BackupError.accessDenied("Cannot access repository location")
            }
            
            // Create repository directory if needed
            if !fileManager.fileExists(atPath: path.path) {
                logger.debug("Creating repository directory at: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
                try fileManager.createDirectory(at: path, withIntermediateDirectories: true)
            }
            
            // Initialize repository
            logger.debug("Initializing repository with restic", privacy: .public, file: #file, function: #function, line: #line)
            let repository = Repository(
                name: path.lastPathComponent,
                path: path.path,
                credentials: RepositoryCredentials(password: password)
            )
            
            try await resticService.initializeRepository(repository)
            logger.info("Successfully created repository at: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
            return repository
            
        } catch {
            logger.error("Failed to create repository: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw BackupError.creationFailed(error.localizedDescription)
        }
    }
    
    func initializeRepository(at path: URL, password: String) async throws -> Repository {
        logger.info("Initializing existing repository at: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Validate path access
            logger.debug("Validating access to path: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
            guard try bookmarkService.validateBookmark(for: path) else {
                logger.error("Cannot access repository location: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
                throw BackupError.accessDenied("Cannot access repository location")
            }
            
            // Verify repository exists
            guard fileManager.fileExists(atPath: path.path) else {
                logger.error("Repository directory not found at: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
                throw BackupError.notFound("Repository directory not found")
            }
            
            // Initialize repository
            let repository = Repository(
                name: path.lastPathComponent,
                path: path.path,
                credentials: RepositoryCredentials(password: password)
            )
            
            // Verify repository is valid
            logger.debug("Verifying repository integrity", privacy: .public, file: #file, function: #function, line: #line)
            try await resticService.verifyRepository(repository)
            
            logger.info("Successfully initialized repository at: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
            return repository
            
        } catch {
            logger.error("Failed to initialize repository: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw BackupError.initializationFailed(error.localizedDescription)
        }
    }
    
    func deleteRepository(_ repository: Repository) async throws {
        logger.info("Deleting repository at: \(repository.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            let path = URL(fileURLWithPath: repository.path)
            
            // Validate path access
            logger.debug("Validating access to path: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
            guard try bookmarkService.validateBookmark(for: path) else {
                logger.error("Cannot access repository location: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
                throw BackupError.accessDenied("Cannot access repository location")
            }
            
            // Verify repository exists
            guard fileManager.fileExists(atPath: path.path) else {
                logger.error("Repository directory not found at: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
                throw BackupError.notFound("Repository directory not found")
            }
            
            // Delete repository directory
            logger.debug("Removing repository directory", privacy: .public, file: #file, function: #function, line: #line)
            try fileManager.removeItem(at: path)
            
            logger.info("Successfully deleted repository at: \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
            
        } catch {
            logger.error("Failed to delete repository: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw BackupError.deletionFailed(error.localizedDescription)
        }
    }
    
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        logger.debug("Listing snapshots for repository: \(repository.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            let snapshots = try await resticService.listSnapshots(repository: repository)
            logger.info("Found \(snapshots.count) snapshots in repository", privacy: .public, file: #file, function: #function, line: #line)
            return snapshots
        } catch {
            logger.error("Failed to list snapshots: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw BackupError.listingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    /// Execute an operation with secure access to URLs
    /// - Parameters:
    ///   - urls: URLs to secure access for
    ///   - operation: Operation to execute
    /// - Returns: Result of operation
    /// - Throws: BackupError if access fails
    private func withSecureAccess<T>(
        to urls: [URL],
        operation: () async throws -> T
    ) async throws -> T {
        var accessedURLs: [URL] = []
        var securedURLs: [URL] = []
        
        do {
            // Start accessing security-scoped resources
            for url in urls {
                if try bookmarkService.startAccessing(url) {
                    accessedURLs.append(url)
                    securedURLs.append(url)
                    logger.debug("Secured access to: \(url.path, privacy: .public)", file: #file, function: #function, line: #line)
                } else {
                    logger.error("Failed to secure access to: \(url.path, privacy: .public)", file: #file, function: #function, line: #line)
                    throw BackupError.accessDenied("Could not access \(url.path)")
                }
            }
            
            // Execute operation
            return try await operation()
        } catch {
            logger.error("Operation failed: \(error.localizedDescription, privacy: .public)", file: #file, function: #function, line: #line)
            throw error
        } finally {
            // Stop accessing in reverse order
            for url in securedURLs.reversed() {
                bookmarkService.stopAccessing(url)
                logger.debug("Released access to: \(url.path, privacy: .public)", file: #file, function: #function, line: #line)
            }
        }
    }
}

// MARK: - Backup Errors

/// Errors that can occur during backup operations
enum BackupError: LocalizedError {
    case accessDenied(String)
    case repositoryNotFound
    case invalidRepository
    case fileSystemError(String)
    case operationFailed(String)
    case creationFailed(String)
    case initializationFailed(String)
    case deletionFailed(String)
    case listingFailed(String)
    case notFound(String)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied(let path):
            return "Access denied to \(path)"
        case .repositoryNotFound:
            return "Repository not found"
        case .invalidRepository:
            return "Invalid repository"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .creationFailed(let message):
            return "Failed to create repository: \(message)"
        case .initializationFailed(let message):
            return "Failed to initialize repository: \(message)"
        case .deletionFailed(let message):
            return "Failed to delete repository: \(message)"
        case .listingFailed(let message):
            return "Failed to list snapshots: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        }
    }
}
