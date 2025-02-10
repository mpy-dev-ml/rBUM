import Core
import Foundation

@RestoreActor
extension RestoreService {
    // MARK: - Operation Management

    /// Starts a restore operation.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the operation
    ///   - snapshot: The snapshot to restore from
    ///   - repository: The source repository
    ///   - target: The target path
    /// - Throws: RestoreError if operation cannot be started
    func startRestoreOperation(
        _ id: UUID,
        snapshot: ResticSnapshot,
        repository: Repository,
        target: String
    ) async throws {
        // Add to active operations
        activeRestores.insert(id)

        // Log operation start
        logger.info(
            "Starting restore operation",
            metadata: [
                "operation": .string(id.uuidString),
                "snapshot": .string(snapshot.id),
                "repository": .string(repository.id.uuidString),
                "target": .string(target),
            ],
            file: #file,
            function: #function,
            line: #line
        )
    }

    /// Completes a restore operation.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the operation
    ///   - success: Whether the operation was successful
    ///   - error: Optional error if operation failed
    func completeRestoreOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async {
        // Remove from active operations
        activeRestores.remove(id)

        // Log completion
        logger.info(
            "Completed restore operation",
            metadata: [
                "operation": .string(id.uuidString),
                "success": .string(success ? "true" : "false"),
                "error": error.map { .string($0.localizedDescription) } ?? .string("none"),
            ],
            file: #file,
            function: #function,
            line: #line
        )
    }

    /// Cancels a restore operation.
    ///
    /// - Parameter id: The unique identifier for the operation
    /// - Throws: RestoreError if operation cannot be cancelled
    func cancelRestoreOperation(_ id: UUID) async throws {
        // Check if operation exists
        guard activeRestores.contains(id) else {
            throw RestoreError.operationNotFound
        }

        // Remove from active operations
        activeRestores.remove(id)

        // Log cancellation
        logger.info(
            "Cancelled restore operation",
            metadata: ["operation": .string(id.uuidString)],
            file: #file,
            function: #function,
            line: #line
        )
    }

    /// Gets all active restore operations.
    ///
    /// - Returns: Set of active operation IDs
    func getActiveOperations() async -> Set<UUID> {
        activeRestores
    }

    /// Cancels all active restore operations.
    ///
    /// - Throws: RestoreError if operations cannot be cancelled
    func cancelAllOperations() async throws {
        // Get active operations
        let operations = activeRestores

        // Cancel each operation
        for id in operations {
            try await cancelRestoreOperation(id)
        }
    }
}
