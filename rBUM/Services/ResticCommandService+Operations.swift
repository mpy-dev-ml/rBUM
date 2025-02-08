import Core
import Foundation

extension ResticCommandService {
    // MARK: - Operation Management
    
    /// Starts a Restic operation.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the operation
    ///   - command: The command to execute
    ///   - repository: The target repository
    /// - Throws: ResticCommandError if operation cannot be started
    func startResticOperation(
        _ id: UUID,
        command: ResticCommand,
        repository: Repository
    ) async throws {
        // Add to active operations
        accessQueue.async(flags: .barrier) {
            self.activeOperations.insert(id)
        }
        
        // Log operation start
        logger.info(
            "Starting Restic operation",
            metadata: [
                "operation": .string(id.uuidString),
                "command": .string(command.rawValue),
                "repository": .string(repository.id.uuidString)
            ],
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    /// Completes a Restic operation.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the operation
    ///   - success: Whether the operation was successful
    ///   - error: Optional error if operation failed
    func completeResticOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async {
        // Remove from active operations
        accessQueue.async(flags: .barrier) {
            self.activeOperations.remove(id)
        }
        
        // Log completion
        logger.info(
            "Completed Restic operation",
            metadata: [
                "operation": .string(id.uuidString),
                "success": .string(success ? "true" : "false"),
                "error": error.map { .string($0.localizedDescription) } ?? .string("none")
            ],
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    /// Cancels a Restic operation.
    ///
    /// - Parameter id: The unique identifier for the operation
    /// - Throws: ResticCommandError if operation cannot be cancelled
    func cancelResticOperation(_ id: UUID) async throws {
        // Check if operation exists
        guard accessQueue.sync(execute: { activeOperations.contains(id) }) else {
            throw ResticCommandError.operationNotFound
        }
        
        // Remove from active operations
        accessQueue.async(flags: .barrier) {
            self.activeOperations.remove(id)
        }
        
        // Log cancellation
        logger.info(
            "Cancelled Restic operation",
            metadata: ["operation": .string(id.uuidString)],
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    /// Gets all active Restic operations.
    ///
    /// - Returns: Set of active operation IDs
    func getActiveOperations() -> Set<UUID> {
        accessQueue.sync { activeOperations }
    }
    
    /// Cancels all active Restic operations.
    ///
    /// - Throws: ResticCommandError if operations cannot be cancelled
    func cancelAllOperations() async throws {
        // Get active operations
        let operations = getActiveOperations()
        
        // Cancel each operation
        for id in operations {
            try await cancelResticOperation(id)
        }
    }
    
    /// Pauses all active Restic operations.
    ///
    /// - Throws: ResticCommandError if operations cannot be paused
    public func pauseAllOperations() async throws {
        logger.info(
            "Pausing all backup operations",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Signal all active operations to pause
        for operation in activeOperations {
            try await operation.pause()
        }
    }
    
    /// Resumes all paused Restic operations.
    ///
    /// - Throws: ResticCommandError if operations cannot be resumed
    public func resumeAllOperations() async throws {
        logger.info(
            "Resuming all backup operations",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Resume all paused operations
        for operation in activeOperations where operation.isPaused {
            try await operation.resume()
        }
    }
}
