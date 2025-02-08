import Foundation

extension SnapshotListViewModel {
    // MARK: - Snapshot Restoration

    /// Start the snapshot restoration process
    /// - Parameters:
    ///   - snapshot: The snapshot to restore
    ///   - destination: The destination URL for the restored files
    func restoreSnapshot(_ snapshot: ResticSnapshot, to destination: URL) async {
        do {
            try await handleSnapshotRestoration(snapshot, to: destination)
        } catch {
            await handleError(error)
        }
    }

    /// Handle the snapshot restoration process
    /// - Parameters:
    ///   - snapshot: The snapshot to restore
    ///   - destination: The destination URL for the restored files
    private func handleSnapshotRestoration(_ snapshot: ResticSnapshot, to destination: URL) async throws {
        isRestoringSnapshot = true
        currentOperation = .restoring

        defer {
            isRestoringSnapshot = false
            currentOperation = nil
        }

        // Validate repository access
        try await validateRepositoryAccess(repository)

        // Create progress tracker
        let progress = Progress(totalUnitCount: 100)
        self.progress = progress

        // Start restoration
        try await restoreService.restore(
            snapshot: snapshot,
            from: repository,
            to: destination,
            progress: progress
        )

        // Update UI
        showRestoreSheet = false
        restorePath = nil
    }

    /// Cancel the current restoration operation
    func cancelRestoration() {
        restoreService.cancelRestore()
        isRestoringSnapshot = false
        currentOperation = nil
        progress = nil
    }
}
