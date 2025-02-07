import Core
import Foundation

@RestoreActor
extension RestoreService {
    // MARK: - Validation
    
    /// Validates restore prerequisites.
    ///
    /// - Parameters:
    ///   - snapshot: The snapshot to restore from
    ///   - repository: The source repository
    ///   - target: The target path
    /// - Throws: RestoreError if validation fails
    func validateRestorePrerequisites(
        snapshot: ResticSnapshot,
        repository: Repository,
        target: String
    ) async throws {
        // Validate snapshot
        try await validateSnapshot(snapshot, in: repository)
        
        // Validate target
        try await validateTarget(URL(fileURLWithPath: target))
        
        // Verify permissions
        guard try await verifyPermissions(for: URL(fileURLWithPath: target)) else {
            throw RestoreError.insufficientPermissions
        }
    }
    
    /// Validates a snapshot.
    ///
    /// - Parameters:
    ///   - snapshot: The snapshot to validate
    ///   - repository: The repository containing the snapshot
    /// - Throws: RestoreError if validation fails
    private func validateSnapshot(
        _ snapshot: ResticSnapshot,
        in repository: Repository
    ) async throws {
        // Check if snapshot exists
        let snapshots = try await listSnapshots(in: repository)
        guard snapshots.contains(where: { $0.id == snapshot.id }) else {
            throw RestoreError.snapshotNotFound
        }
        
        // Check if snapshot is accessible
        guard try await resticService.check(repository) else {
            throw RestoreError.snapshotInaccessible
        }
    }
    
    /// Validates a restore target.
    ///
    /// - Parameter url: The target URL to validate
    /// - Throws: RestoreError if validation fails
    private func validateTarget(_ url: URL) async throws {
        // Check if target exists
        if try await fileManager.fileExists(at: url) {
            // Check if target is writable
            guard try await fileManager.isWritable(at: url) else {
                throw RestoreError.targetNotWritable
            }
            
            // Check if target has enough space
            guard try await hasEnoughSpace(at: url) else {
                throw RestoreError.insufficientSpace
            }
        } else {
            // Check if parent directory exists and is writable
            let parent = url.deletingLastPathComponent()
            guard try await fileManager.fileExists(at: parent) else {
                throw RestoreError.targetNotFound
            }
            
            guard try await fileManager.isWritable(at: parent) else {
                throw RestoreError.targetNotWritable
            }
            
            // Check if parent has enough space
            guard try await hasEnoughSpace(at: parent) else {
                throw RestoreError.insufficientSpace
            }
        }
    }
    
    /// Verifies permissions for a URL.
    ///
    /// - Parameter url: The URL to verify permissions for
    /// - Returns: True if we have required permissions
    /// - Throws: RestoreError if verification fails
    func verifyPermissions(for url: URL) async throws -> Bool {
        // Check security-scoped access
        guard try await securityService.hasAccess(to: url) else {
            // Request permission if we don't have it
            return try await securityService.requestAccess(to: url)
        }
        
        return true
    }
    
    /// Checks if there is enough space at a URL.
    ///
    /// - Parameter url: The URL to check space at
    /// - Returns: True if there is enough space
    /// - Throws: RestoreError if check fails
    private func hasEnoughSpace(at url: URL) async throws -> Bool {
        // Get available space
        let available = try await fileManager.availableSpace(at: url)
        
        // For now, require at least 1GB
        // TODO: Calculate required space based on snapshot size
        let required: UInt64 = 1024 * 1024 * 1024
        
        return available >= required
    }
}
