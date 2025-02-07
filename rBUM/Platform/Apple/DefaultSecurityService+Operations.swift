import AppKit
import Core
import Foundation

extension DefaultSecurityService {
    // MARK: - Operation Management
    
    /// Starts a security operation.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the operation
    ///   - type: The type of operation being started
    ///   - url: The URL associated with the operation
    /// - Throws: SecurityError if operation cannot be started
    func startSecurityOperation(
        _ id: UUID,
        type: SecurityOperationType,
        url: URL
    ) async throws {
        // Record operation start
        let operation = SecurityOperation(
            id: id,
            type: type,
            url: url,
            timestamp: Date(),
            status: .inProgress
        )
        
        // Add to active operations
        accessQueue.async(flags: .barrier) {
            self.activeOperations.insert(id)
        }
        
        // Log operation start
        logger.info("Starting security operation", metadata: [
            "operation": .string(id.uuidString),
            "type": .string(type.rawValue),
            "url": .string(url.path)
        ])
    }
    
    /// Completes a security operation.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the operation
    ///   - success: Whether the operation was successful
    ///   - error: Optional error if operation failed
    /// - Throws: SecurityError if operation cannot be completed
    func completeSecurityOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async throws {
        // Remove from active operations
        accessQueue.async(flags: .barrier) {
            self.activeOperations.remove(id)
        }
        
        // Log completion
        logger.info("Completed security operation", metadata: [
            "operation": .string(id.uuidString),
            "success": .string(success ? "true" : "false"),
            "error": error.map { .string($0.localizedDescription) } ?? .string("none")
        ])
    }
    
    /// Cancels a security operation.
    ///
    /// - Parameter id: The unique identifier for the operation
    /// - Throws: SecurityError if operation cannot be cancelled
    func cancelSecurityOperation(_ id: UUID) async throws {
        // Create operation ID
        let operationId = UUID()
        
        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .operationCancellation,
                url: URL(fileURLWithPath: "/")
            )
            
            // Remove from active operations
            accessQueue.async(flags: .barrier) {
                self.activeOperations.remove(id)
            }
            
            // Complete operation
            try await completeSecurityOperation(operationId, success: true)
            
        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Gets the status of a security operation.
    ///
    /// - Parameter id: The unique identifier for the operation
    /// - Returns: True if operation is active
    func isOperationActive(_ id: UUID) -> Bool {
        accessQueue.sync {
            activeOperations.contains(id)
        }
    }
    
    /// Gets all active security operations.
    ///
    /// - Returns: Set of active operation IDs
    func getActiveOperations() -> Set<UUID> {
        accessQueue.sync {
            activeOperations
        }
    }
    
    /// Cancels all active security operations.
    ///
    /// - Throws: SecurityError if operations cannot be cancelled
    func cancelAllOperations() async throws {
        // Get active operations
        let operations = getActiveOperations()
        
        // Cancel each operation
        for id in operations {
            try await cancelSecurityOperation(id)
        }
    }
}
