//
//  BackupViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import SwiftUI
import Core

/// BackupViewModel manages the state and operations for creating and managing backups.
/// It handles:
/// - Backup source management
/// - Backup configuration
/// - Backup execution and monitoring
/// - Error handling and progress tracking
/// - Security validation and access control
///
/// This view model follows the MVVM pattern and is designed to be used with SwiftUI views.
/// It integrates with Core services through protocol-based abstractions for improved testability
/// and platform independence.
///
/// Example usage:
/// ```swift
/// let viewModel = BackupViewModel(
///     repository: repository,
///     backupService: backupService,
///     credentialsService: credentialsService,
///     bookmarkService: bookmarkService,
///     securityService: securityService
/// )
///
/// // Add a source
/// try await viewModel.addSource(sourceURL)
///
/// // Start backup
/// await viewModel.startBackup()
/// ```
@MainActor
final class BackupViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Current backup configuration including sources, repository, and settings.
    /// This property is published to enable SwiftUI view updates when the configuration changes.
    @Published private(set) var configuration: BackupConfiguration
    
    /// Flag indicating whether to show an error alert to the user.
    /// Set to true when an error occurs that requires user attention.
    @Published var showError = false
    
    /// Tracks the progress of the current backup operation.
    /// Updates are published to enable real-time progress display in the UI.
    @Published private(set) var progress: ProgressTracker?
    
    /// Error message to display to the user.
    /// Set when an operation fails and requires user notification.
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// Service for performing backup operations.
    /// Handles the actual execution of Restic commands.
    private let backupService: BackupServiceProtocol
    
    /// Service for managing repository credentials.
    /// Handles secure storage and retrieval of credentials.
    private let credentialsService: CredentialsServiceProtocol
    
    /// Service for managing security-scoped bookmarks.
    /// Enables persistent access to user-selected files and directories.
    private let bookmarkService: BookmarkServiceProtocol
    
    /// Service for validating security requirements.
    /// Ensures operations comply with sandbox restrictions.
    private let securityService: SecurityServiceProtocol
    
    /// Logger for recording operations and errors.
    /// Uses privacy-aware logging for sensitive information.
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    /// Initialises a new backup view model.
    /// - Parameters:
    ///   - repository: The target repository for backups
    ///   - backupService: Service for performing backup operations
    ///   - credentialsService: Service for managing credentials
    ///   - bookmarkService: Service for managing security-scoped bookmarks
    ///   - securityService: Service for validating security requirements
    ///   - logger: Logger for recording operations and errors
    init(
        repository: Repository,
        backupService: BackupServiceProtocol,
        credentialsService: CredentialsServiceProtocol,
        bookmarkService: BookmarkServiceProtocol,
        securityService: SecurityServiceProtocol,
        logger: LoggerProtocol = Logging.logger(for: .backup)
    ) {
        self.configuration = BackupConfiguration(
            sources: [],
            repository: repository,
            settings: .default
        )
        self.backupService = backupService
        self.credentialsService = credentialsService
        self.bookmarkService = bookmarkService
        self.securityService = securityService
        self.logger = logger
        
        logger.debug("Initialized BackupViewModel for repository: \(repository.name)", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    // MARK: - Public Methods
    
    /// Adds a new source to the backup configuration.
    /// - Parameter url: URL of the source to add
    /// - Throws: SecurityError if access validation fails
    ///          BookmarkError if bookmark creation fails
    ///
    /// This method:
    /// 1. Validates that the source isn't already added
    /// 2. Validates access permissions
    /// 3. Creates a security-scoped bookmark
    /// 4. Updates the configuration
    func addSource(_ url: URL) async throws {
        logger.debug("Adding source to backup: \(url.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        // Check if source already exists
        guard !configuration.sources.contains(where: { $0.url == url }) else {
            logger.debug("Source already exists: \(url.path)", privacy: .public, file: #file, function: #function, line: #line)
            return
        }
        
        do {
            // Validate access
            try securityService.validateAccess(to: url)
            
            // Create bookmark for persistence
            let bookmark = try bookmarkService.createBookmark(for: url)
            
            // Create new source
            let source = BackupSource(url: url)
            
            // Update configuration
            configuration = BackupConfiguration(
                sources: configuration.sources + [source],
                repository: configuration.repository,
                tags: configuration.tags,
                schedule: configuration.schedule,
                settings: configuration.settings
            )
            
            logger.info("Successfully added source: \(url.path)", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to add source: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
    
    /// Removes a source from the backup configuration.
    /// - Parameter url: URL of the source to remove
    ///
    /// This method:
    /// 1. Removes the source from the configuration
    /// 2. Cleans up any associated bookmarks
    /// 3. Updates the UI state
    func removeSource(_ url: URL) {
        logger.debug("Removing source from backup: \(url.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        // Remove bookmark
        do {
            try bookmarkService.removeBookmark(for: url)
        } catch {
            logger.warning("Failed to remove bookmark: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
        }
        
        // Update configuration
        configuration = BackupConfiguration(
            sources: configuration.sources.filter { $0.url != url },
            repository: configuration.repository,
            tags: configuration.tags,
            schedule: configuration.schedule,
            settings: configuration.settings
        )
        
        logger.info("Successfully removed source: \(url.path)", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    /// Starts the backup operation.
    ///
    /// This method:
    /// 1. Validates the configuration
    /// 2. Retrieves repository credentials
    /// 3. Initialises progress tracking
    /// 4. Executes the backup operation
    /// 5. Handles errors and updates UI state
    func startBackup() async {
        guard !configuration.sources.isEmpty else {
            logger.warning("Cannot start backup: no sources selected", privacy: .public, file: #file, function: #function, line: #line)
            errorMessage = "Please select at least one source to backup"
            showError = true
            return
        }
        
        logger.info("Starting backup operation", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Get repository credentials
            let credentials = try await credentialsService.getCredentials(for: configuration.repository)
            
            // Create progress tracker
            let tracker = ProgressTracker(total: Int64(configuration.sources.count))
            self.progress = tracker
            
            // Start backup
            try await backupService.createBackup(
                paths: configuration.sources.map(\.url),
                to: configuration.repository,
                credentials: credentials,
                tags: configuration.tags,
                onProgress: { [weak self] progress in
                    self?.progress?.update(processed: Int64(progress.processedFiles))
                },
                onStatusChange: { [weak self] status in
                    switch status {
                    case .preparing:
                        self?.logger.info("Preparing backup", privacy: .public, file: #file, function: #function, line: #line)
                    case .backing:
                        self?.logger.info("Backing up files", privacy: .public, file: #file, function: #function, line: #line)
                    case .completed:
                        self?.logger.info("Backup completed successfully", privacy: .public, file: #file, function: #function, line: #line)
                        self?.progress?.complete()
                    case .failed(let error):
                        self?.handleError(error)
                    }
                }
            )
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: Error) {
        progress?.fail(error)
        
        switch error {
        case let resticError as ResticError:
            errorMessage = resticError.localizedDescription
        case let securityError as SecurityError:
            errorMessage = securityError.localizedDescription
        default:
            errorMessage = error.localizedDescription
        }
        
        logger.error("Backup failed: \(errorMessage ?? "Unknown error")", privacy: .public, file: #file, function: #function, line: #line)
        showError = true
    }
}
