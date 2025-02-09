import Core
import Foundation

extension BackupViewModel {
    // MARK: - Backup Operations

    /// Start a new backup operation
    func startBackup() async {
        do {
            // Validate access before starting
            try await validateSourceAccess()
            try await validateRepositoryAccess()
            
            // Update UI state
            await updateBackupStatus(.preparing)
            
            // Start the backup
            try await backupService.startBackup(configuration)
            
            logger.debug("Backup started successfully", privacy: .public)
            
        } catch {
            logger.error("Failed to start backup: \(error.localizedDescription)", privacy: .public)
            await updateBackupStatus(.failed(error as? ResticBackupError ?? .unknown(error)))
        }
    }
    
    /// Cancel the current backup operation
    func cancelBackup() async {
        do {
            try await backupService.cancelBackup()
            await updateBackupStatus(.cancelled)
            
            // Clean up access after cancellation
            cleanupAccess()
            
            logger.debug("Backup cancelled by user", privacy: .public)
            
            // Show cancellation notification
            await notificationService.sendNotification(
                title: "Backup Cancelled",
                body: "The backup operation was cancelled",
                type: .warning
            )
        } catch {
            logger.error("Failed to cancel backup: \(error.localizedDescription)", privacy: .public)
            self.error = error
            showError = true
        }
    }

    /// Perform the backup operation
    private func performBackup() async throws {
        guard !isBackingUp else { return }

        isBackingUp = true
        currentOperation = .backing

        defer {
            isBackingUp = false
            currentOperation = nil
        }

        // Validate prerequisites
        try await validateBackupPrerequisites()

        // Create progress tracker
        let progress = Progress(totalUnitCount: 100)
        self.progress = progress

        // Start backup
        try await backupService.backup(
            configuration: configuration,
            progress: progress
        )

        // Update UI
        showBackupSheet = false
    }

    /// Validate backup prerequisites
    private func validateBackupPrerequisites() async throws {
        // Validate source
        try await validateSource()

        // Validate repository
        try await validateRepository()

        // Validate credentials
        try await validateCredentials()
    }

    /// Update backup progress
    private func updateProgress(_ backupProgress: BackupProgress) {
        Task { @MainActor in
            progress?.completedUnitCount = Int64(backupProgress.percentComplete)
            logger.debug("Backup progress: \(backupProgress.percentComplete)%")
        }
    }

    // MARK: - Progress Tracking
    
    /// Update the current backup progress
    /// - Parameter status: The new backup status
    @MainActor
    func updateBackupStatus(_ status: ResticBackupStatus) {
        self.backupStatus = status
        
        switch status {
        case .preparing:
            currentOperation = "Preparing backup..."
            indeterminateProgress = true
            
        case .backing(let progress):
            currentOperation = "Backing up files..."
            indeterminateProgress = false
            currentProgress = progress.percentComplete / 100.0
            processedFiles = progress.filesProcessed
            totalFiles = progress.totalFiles
            
        case .finalising:
            currentOperation = "Finalising backup..."
            indeterminateProgress = true
            
        case .completed:
            currentOperation = "Backup completed"
            indeterminateProgress = false
            currentProgress = 1.0
            showCompletionNotification()
            cleanupAccess() // Clean up access after completion
            
        case .failed(let error):
            currentOperation = "Backup failed"
            indeterminateProgress = false
            self.error = error
            showError = true
            cleanupAccess() // Clean up access after failure
            
        case .cancelled:
            currentOperation = "Backup cancelled"
            indeterminateProgress = false
            cleanupAccess() // Clean up access after cancellation
        }
        
        logger.debug("""
            Backup status updated:
            - Status: \(String(describing: status))
            - Operation: \(currentOperation)
            - Progress: \(currentProgress)
            - Files: \(processedFiles)/\(totalFiles ?? 0)
            """, privacy: .public)
    }
    
    /// Show a notification when backup completes
    private func showCompletionNotification() {
        Task {
            await notificationService.sendNotification(
                title: "Backup Completed",
                body: "Your backup has completed successfully",
                type: .success
            )
        }
    }
    
    /// Reset progress tracking
    func resetProgress() {
        currentOperation = ""
        currentProgress = 0
        indeterminateProgress = false
        processedFiles = 0
        totalFiles = nil
        backupStatus = nil
        cleanupAccess() // Clean up any lingering access
    }
}
