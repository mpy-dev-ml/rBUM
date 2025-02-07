import AppKit
import Core
import Foundation

extension DefaultSecurityService {
    // MARK: - Health Checks
    
    /// Performs a health check of the security service.
    ///
    /// - Returns: True if service is healthy
    /// - Throws: SecurityError if health check fails
    func performHealthCheck() async throws -> Bool {
        // Create operation ID
        let operationId = UUID()
        
        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .healthCheck,
                url: URL(fileURLWithPath: "/")
            )
            
            // Check sandbox health
            guard try await checkSandboxHealth() else {
                throw SecurityError.unhealthyState("Sandbox health check failed")
            }
            
            // Check bookmark health
            guard try await checkBookmarkHealth() else {
                throw SecurityError.unhealthyState("Bookmark health check failed")
            }
            
            // Check operation health
            guard checkOperationHealth() else {
                throw SecurityError.unhealthyState("Operation health check failed")
            }
            
            // Complete operation
            try await completeSecurityOperation(operationId, success: true)
            
            return true
            
        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Checks the health of the sandbox.
    ///
    /// - Returns: True if sandbox is healthy
    /// - Throws: SecurityError if check fails
    private func checkSandboxHealth() async throws -> Bool {
        // Check sandbox container
        guard try await validateSandboxAccess() else {
            return false
        }
        
        // Check sandbox monitor
        guard sandboxMonitor.isMonitoring else {
            return false
        }
        
        return true
    }
    
    /// Checks the health of bookmarks.
    ///
    /// - Returns: True if bookmarks are healthy
    /// - Throws: SecurityError if check fails
    private func checkBookmarkHealth() async throws -> Bool {
        // Get all bookmarks
        let bookmarks = try await bookmarkService.getAllBookmarks()
        
        // Check each bookmark
        for (url, bookmark) in bookmarks {
            // Try to resolve bookmark
            var isStale = false
            _ = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            // Delete stale bookmarks
            if isStale {
                try await bookmarkService.deleteBookmark(for: url)
            }
        }
        
        return true
    }
    
    /// Checks the health of operations.
    ///
    /// - Returns: True if operations are healthy
    private func checkOperationHealth() -> Bool {
        // Check for stuck operations
        let operations = getActiveOperations()
        
        return operations.isEmpty
    }
    
    /// Performs cleanup of stale resources.
    ///
    /// - Throws: SecurityError if cleanup fails
    func performCleanup() async throws {
        // Create operation ID
        let operationId = UUID()
        
        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .cleanup,
                url: URL(fileURLWithPath: "/")
            )
            
            // Clean up stale bookmarks
            try await cleanupStaleBookmarks()
            
            // Clean up stuck operations
            try await cleanupStuckOperations()
            
            // Complete operation
            try await completeSecurityOperation(operationId, success: true)
            
        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Cleans up stale bookmarks.
    ///
    /// - Throws: SecurityError if cleanup fails
    private func cleanupStaleBookmarks() async throws {
        // Get all bookmarks
        let bookmarks = try await bookmarkService.getAllBookmarks()
        
        // Check each bookmark
        for (url, bookmark) in bookmarks {
            // Try to resolve bookmark
            var isStale = false
            _ = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            // Delete stale bookmarks
            if isStale {
                try await bookmarkService.deleteBookmark(for: url)
                
                logger.info("Cleaned up stale bookmark", metadata: [
                    "url": .string(url.path)
                ])
            }
        }
    }
    
    /// Cleans up stuck operations.
    ///
    /// - Throws: SecurityError if cleanup fails
    private func cleanupStuckOperations() async throws {
        // Get active operations
        let operations = getActiveOperations()
        
        // Cancel each operation
        for id in operations {
            try await cancelSecurityOperation(id)
            
            logger.info("Cleaned up stuck operation", metadata: [
                "operation": .string(id.uuidString)
            ])
        }
    }
}
