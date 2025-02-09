//
//  BackupViewModel.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Core
import Foundation
import os.log
import SwiftUI

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
@MainActor
final class BackupViewModel: ObservableObject {
    // MARK: - Types

    enum Operation: String {
        case backing = "Backing up"
        case validating = "Validating"
        case configuring = "Configuring"
    }

    // MARK: - Published Properties

    @Published var configuration: BackupConfiguration
    @Published var repository: Repository?
    @Published private(set) var progress: Progress?
    @Published private(set) var isBackingUp = false
    @Published private(set) var currentOperation: Operation?
    @Published var error: Error?
    @Published var showError = false
    @Published var showBackupSheet = false
    @Published private(set) var configurationIssue: String?
    @Published private(set) var backupStatus: ResticBackupStatus?
    @Published private(set) var currentOperationDescription: String = ""
    @Published private(set) var currentProgress: Double = 0
    @Published private(set) var indeterminateProgress: Bool = false
    @Published private(set) var processedFiles: Int = 0
    @Published private(set) var totalFiles: Int?
    @Published var includeHidden: Bool = false
    @Published var verifyAfterBackup: Bool = true

    // MARK: - Private Properties

    private let backupService: BackupServiceProtocol
    private let credentialsService: KeychainCredentialsManagerProtocol
    private let securityService: SecurityServiceProtocol
    private let bookmarkService: BookmarkServiceProtocol
    private let logger: LoggerProtocol

    // MARK: - Initialization

    init(
        repository: Repository? = nil,
        backupService: BackupServiceProtocol,
        credentialsService: KeychainCredentialsManagerProtocol,
        securityService: SecurityServiceProtocol,
        bookmarkService: BookmarkServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.repository = repository
        self.backupService = backupService
        self.credentialsService = credentialsService
        self.securityService = securityService
        self.bookmarkService = bookmarkService
        self.logger = logger
        self.configuration = BackupConfiguration()
    }
}

extension BackupViewModel {
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
        logger.debug("Adding source to backup: \(url.path)", file: #file, function: #function, line: #line)

        // Check if source already exists
        guard !configuration.sources.contains(where: { $0.url == url }) else {
            logger.debug("Source already exists: \(url.path)", file: #file, function: #function, line: #line)
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

            logger.info("Successfully added source: \(url.path)", file: #file, function: #function, line: #line)
        } catch {
            logger.error(
                "Failed to add source: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
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
        logger.debug("Removing source from backup: \(url.path)", file: #file, function: #function, line: #line)

        // Remove bookmark
        do {
            try bookmarkService.removeBookmark(for: url)
        } catch {
            logger.warning(
                "Failed to remove bookmark: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
        }

        // Update configuration
        configuration = BackupConfiguration(
            sources: configuration.sources.filter { $0.url != url },
            repository: configuration.repository,
            tags: configuration.tags,
            schedule: configuration.schedule,
            settings: configuration.settings
        )

        logger.info("Successfully removed source: \(url.path)", file: #file, function: #function, line: #line)
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
            logger.warning("Cannot start backup: no sources selected", file: #file, function: #function, line: #line)
            error = BackupError.missingSource("No source selected")
            showError = true
            return
        }

        logger.info("Starting backup operation", file: #file, function: #function, line: #line)

        do {
            try await handleBackupOperation()
        } catch {
            handleError(error)
        }
    }
}

extension BackupViewModel {
    // MARK: - Private Methods

    private func handleBackupOperation() async throws {
        try await validateBackupPrerequisites()
        try await performBackupOperation()
        try await handleBackupCompletion()
    }

    private func validateBackupPrerequisites() async throws {
        // Validate repository
        try await validateRepository()

        // Validate source
        try await validateSource()

        // Validate configuration
        try await validateConfiguration()
    }

    private func validateRepository() async throws {
        guard let repository = configuration.repository else {
            throw BackupError.missingRepository("No repository selected")
        }

        guard let url = repository.url else {
            throw BackupError.invalidRepository("Repository URL is missing")
        }

        guard try await securityService.validateAccess(to: url) else {
            throw BackupError.accessDenied("Cannot access repository")
        }

        guard try await securityService.validateWriteAccess(to: url) else {
            throw BackupError.accessDenied("Cannot write to repository")
        }
    }

    private func validateSource() async throws {
        guard let source = configuration.sources.first else {
            throw BackupError.missingSource("No source selected")
        }

        guard source.url.isFileURL else {
            throw BackupError.invalidSource("Source must be a file URL")
        }

        guard try await securityService.validateAccess(to: source.url) else {
            throw BackupError.accessDenied("Cannot access source")
        }

        guard try await securityService.validateReadAccess(to: source.url) else {
            throw BackupError.accessDenied("Cannot read from source")
        }
    }

    private func validateConfiguration() async throws {
        guard let configuration = configuration else {
            throw BackupError.missingConfiguration("No backup configuration")
        }

        // Validate compression settings
        if configuration.settings.compression {
            guard try await validateCompressionSettings() else {
                throw BackupError.invalidConfiguration("Invalid compression settings")
            }
        }

        // Validate encryption settings
        if configuration.settings.encryption {
            guard try await validateEncryptionSettings() else {
                throw BackupError.invalidConfiguration("Invalid encryption settings")
            }
        }

        // Validate schedule settings
        if configuration.schedule != nil {
            guard try await validateScheduleSettings() else {
                throw BackupError.invalidConfiguration("Invalid schedule settings")
            }
        }
    }

    private func validateCompressionSettings() async throws -> Bool {
        guard let configuration = configuration else { return false }

        // Check compression level
        guard (1...9).contains(configuration.settings.compressionLevel) else {
            return false
        }

        // Check available system resources
        let systemInfo = try await systemMonitor.getSystemInfo()
        guard systemInfo.availableMemory > minimumMemoryForCompression else {
            return false
        }

        return true
    }

    private func validateEncryptionSettings() async throws -> Bool {
        guard let configuration = configuration else { return false }

        // Check encryption key
        guard !configuration.settings.encryptionKey.isEmpty else {
            return false
        }

        // Validate key strength
        guard try await securityService.validateKeyStrength(configuration.settings.encryptionKey) else {
            return false
        }

        return true
    }

    private func validateScheduleSettings() async throws -> Bool {
        guard let configuration = configuration else { return false }

        // Check schedule interval
        guard configuration.schedule?.interval > 0 else {
            return false
        }

        // Check schedule time
        guard let scheduleTime = configuration.schedule?.time else {
            return false
        }

        // Validate schedule time is in the future
        let now = Date()
        guard scheduleTime > now else {
            return false
        }

        return true
    }

    private func performBackupOperation() async throws {
        guard let repository = configuration.repository,
              let source = configuration.sources.first,
              let configuration = configuration else {
            throw BackupError.invalidState("Missing required state")
        }

        // Update UI state
        progress = Progress(totalUnitCount: 100)

        do {
            // Get repository credentials
            let credentials = try await credentialsService.getCredentials(for: repository)

            // Create backup source
            let backupSource = BackupSource(
                url: source.url,
                metadata: source.metadata
            )

            // Create backup configuration
            let backupConfig = BackupConfiguration(
                compression: configuration.settings.compression,
                compressionLevel: configuration.settings.compressionLevel,
                encryption: configuration.settings.encryption,
                encryptionKey: configuration.settings.encryptionKey,
                filters: configuration.settings.filters,
                tags: configuration.tags
            )

            // Execute backup
            try await backupService.createBackup(
                paths: [source.url],
                to: repository,
                with: backupConfig,
                credentials: credentials,
                progress: { [weak self] progress in
                    self?.updateProgress(progress)
                }
            )

        } catch {
            handleError(error)
            throw error
        }
    }

    private func updateProgress(_ backupProgress: BackupProgress) {
        Task { @MainActor in
            progress?.completedUnitCount = Int64(backupProgress.percentComplete)

            // Log progress
            logger.debug("Backup progress updated", metadata: [
                "processed_files": .string("\(backupProgress.processedFiles)"),
                "processed_bytes": .string("\(backupProgress.processedBytes)"),
                "percent_complete": .string("\(backupProgress.percentComplete)")
            ])
        }
    }

    private func handleBackupError(_ error: Error) {
        Task { @MainActor in
            progress?.cancel()

            switch error {
            case let resticError as ResticError:
                error = resticError
            case let securityError as SecurityError:
                error = securityError
            default:
                error = error
            }

            logger.error(
                "Backup failed: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            showError = true
        }
    }

    private func handleError(_ error: Error) {
        Task { @MainActor in
            progress?.cancel()

            switch error {
            case let resticError as ResticError:
                error = resticError
            case let securityError as SecurityError:
                error = securityError
            default:
                error = error
            }

            logger.error(
                """
                Backup failed: \(error.localizedDescription)
                File: \(#file)
                Function: \(#function)
                Line: \(#line)
                """,
                metadata: [
                    "error": .string("\(error)")
                ]
            )
            showError = true
        }
    }

    private func handleBackupCompletion() async throws {
        Task { @MainActor in
            progress?.completedUnitCount = 100

            // Log completion
            logger.info("Backup completed successfully", metadata: [
                "repository": .string(configuration.repository?.id.uuidString ?? "unknown"),
                "source": .string(configuration.sources.first?.url.path ?? "unknown")
            ])
        }
    }
}
