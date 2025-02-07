import Foundation
import os.log

// MARK: - HealthCheckable Implementation
@available(macOS 13.0, *)
extension ResticXPCService {
    /// Updates the health status of the XPC service by performing a health check
    /// If the health check fails, the service is marked as unhealthy and the error is logged
    @objc public func updateHealthStatus() async {
        do {
            isHealthy = try await performHealthCheck()
        } catch {
            logger.error(
                "Health check failed: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            isHealthy = false
        }
    }
    
    /// Performs a health check on the XPC service
    /// - Returns: A boolean indicating if the service is healthy
    /// - Throws: SecurityError.xpcValidationFailed if the XPC connection is invalid
    @objc public func performHealthCheck() async throws -> Bool {
        logger.debug(
            "Performing health check",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Validate XPC connection
        let isValid = try await securityService.validateXPCConnection(connection)
        
        // Check if connection is valid (NSXPCConnection doesn't have isValid, 
        // but we can check if it's not invalidated)
        if !isValid || connection.invalidationHandler == nil {
            throw SecurityError.xpcValidationFailed("XPC connection is invalidated")
        }
        
        return true
    }
}
