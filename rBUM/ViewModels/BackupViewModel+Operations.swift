import Core
import Foundation

extension BackupViewModel {
    // MARK: - Backup Operations

    /// Start the backup operation
    func startBackup() async {
        do {
            try await performBackup()
        } catch {
            await handleError(error)
        }
    }

    /// Cancel the current backup operation
    func cancelBackup() {
        backupService.cancelBackup()
        isBackingUp = false
        currentOperation = nil
        progress = nil
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
}
