import AppKit
import Core
import Foundation
import Security

/// Extension providing metrics and health check capabilities for DefaultSecurityService
extension DefaultSecurityService {
    // MARK: - Metrics and Health
    
    /// Collects metrics about the security service's current state.
    ///
    /// - Returns: Dictionary containing service metrics
    public func collectMetrics() -> [String: Any] {
        return accessQueue.sync {
            [
                "activeOperations": activeOperations.count,
                "isHealthy": isHealthy,
                "sandboxCompliant": true
            ]
        }
    }
    
    /// Performs a health check of the security service.
    ///
    /// - Returns: Boolean indicating whether the service is healthy
    public func performHealthCheck() async throws -> Bool {
        let id = UUID()
        let type: SecurityOperationType = .healthCheck
        
        return try await withOperation(id: id, type: type) {
            // Check active operations
            guard isHealthy else {
                return false
            }
            
            // Check sandbox container
            guard try await validateSandboxContainer() else {
                return false
            }
            
            // Check bookmark service
            guard try await bookmarkService.performHealthCheck() else {
                return false
            }
            
            // Check keychain service
            guard try await keychainService.performHealthCheck() else {
                return false
            }
            
            return true
        }
    }
    
    /// Cleans up any resources that are no longer needed.
    public func cleanup() async throws {
        let id = UUID()
        let type: SecurityOperationType = .cleanup
        
        try await withOperation(id: id, type: type) {
            // Clean up bookmark service
            try await bookmarkService.cleanup()
            
            // Clean up keychain service
            try await keychainService.cleanup()
            
            // Clean up sandbox monitor
            sandboxMonitor.cleanup()
        }
    }
}
