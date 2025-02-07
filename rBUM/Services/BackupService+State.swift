import Core
import Foundation

/// Extension providing state management for BackupService
extension BackupService {
    // MARK: - State Management
    
    /// Actor for managing backup state in a thread-safe manner
    actor BackupState {
        /// Set of active backup operation IDs
        private var activeBackups: Set<UUID> = []
        
        /// Cached health status of the service
        private var cachedHealthStatus: Bool = true
        
        /// Adds a backup operation ID to the active set
        func insert(_ id: UUID) {
            activeBackups.insert(id)
            updateCachedHealth()
        }
        
        /// Removes a backup operation ID from the active set
        func remove(_ id: UUID) {
            activeBackups.remove(id)
            updateCachedHealth()
        }
        
        /// Checks if there are any active backup operations
        var isEmpty: Bool {
            activeBackups.isEmpty
        }
        
        /// Updates the cached health status based on active operations
        private func updateCachedHealth() {
            cachedHealthStatus = activeBackups.isEmpty
        }
    }
    
    /// Updates the service's health status.
    ///
    /// The service is considered healthy when:
    /// - No backup operations are in progress
    /// - The Restic service is healthy
    public func updateHealthStatus() async {
        let isEmpty = await backupState.isEmpty
        let resticHealthy = await (try? resticService.performHealthCheck()) ?? false
        isHealthy = isEmpty && resticHealthy
    }
    
    /// Performs a backup operation with proper state management.
    ///
    /// - Parameters:
    ///   - id: Operation identifier
    ///   - source: Source of the backup
    ///   - operation: The backup operation to perform
    internal func withBackupOperation(
        id: UUID,
        source: BackupSource,
        operation: () async throws -> Void
    ) async throws {
        // Record operation start
        await backupState.insert(id)
        
        do {
            // Perform operation
            try await operation()
            
            // Record successful completion
            await backupState.remove(id)
        } catch {
            // Record failure and rethrow
            await backupState.remove(id)
            throw error
        }
    }
}
