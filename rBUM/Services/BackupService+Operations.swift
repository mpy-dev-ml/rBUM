import Core
import Foundation

extension BackupService {
    // MARK: - Operation Management

    /// Starts a backup operation.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the operation
    ///   - source: The source URL for the backup
    ///   - destination: The destination repository
    ///   - options: Backup options
    /// - Throws: BackupError if operation cannot be started
    func startBackupOperation(
        _ id: UUID,
        source: URL,
        destination: Repository,
        options: BackupOptions
    ) async throws {
        // Record operation start
        let operation = BackupOperation(
            id: id,
            source: source,
            destination: destination,
            options: options,
            timestamp: Date(),
            status: .inProgress
        )

        // Add to active operations
        await backupState.insert(id)

        // Log operation start
        logger.info("Starting backup operation", metadata: [
            "operation": .string(id.uuidString),
            "source": .string(source.path),
            "destination": .string(destination.id.uuidString),
        ])
    }

    /// Completes a backup operation.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the operation
    ///   - success: Whether the operation was successful
    ///   - error: Optional error if operation failed
    /// - Throws: BackupError if operation cannot be completed
    func completeBackupOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async throws {
        // Remove from active operations
        await backupState.remove(id)

        // Log completion
        logger.info("Completed backup operation", metadata: [
            "operation": .string(id.uuidString),
            "success": .string(success ? "true" : "false"),
            "error": error.map { .string($0.localizedDescription) } ?? .string("none"),
        ])
    }

    /// Cancels a backup operation.
    ///
    /// - Parameter id: The unique identifier for the operation
    /// - Throws: BackupError if operation cannot be cancelled
    func cancelBackupOperation(_ id: UUID) async throws {
        // Create operation ID
        let operationId = UUID()

        do {
            // Start operation
            try await startBackupOperation(
                operationId,
                source: URL(fileURLWithPath: "/"),
                destination: Repository(id: UUID(), path: "/"),
                options: BackupOptions()
            )

            // Remove from active operations
            await backupState.remove(id)

            // Complete operation
            try await completeBackupOperation(operationId, success: true)

        } catch {
            // Handle failure
            try await completeBackupOperation(operationId, success: false, error: error)
            throw error
        }
    }

    /// Gets the status of a backup operation.
    ///
    /// - Parameter id: The unique identifier for the operation
    /// - Returns: True if operation is active
    func isOperationActive(_ id: UUID) async -> Bool {
        await backupState.activeBackups.contains(id)
    }

    /// Gets all active backup operations.
    ///
    /// - Returns: Set of active operation IDs
    func getActiveOperations() async -> Set<UUID> {
        await backupState.activeBackups
    }

    /// Cancels all active backup operations.
    ///
    /// - Throws: BackupError if operations cannot be cancelled
    func cancelAllOperations() async throws {
        // Get active operations
        let operations = await getActiveOperations()

        // Cancel each operation
        for id in operations {
            try await cancelBackupOperation(id)
        }
    }
}
