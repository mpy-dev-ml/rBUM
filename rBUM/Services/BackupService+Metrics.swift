import Core
import Foundation

/// Extension providing metrics and health check capabilities for BackupService
public extension BackupService {
    // MARK: - Metrics and Health

    /// Collects metrics about the backup service's current state.
    ///
    /// - Returns: Dictionary containing service metrics
    func collectMetrics() -> [String: Any] {
        [
            "isHealthy": isHealthy,
            "maxConcurrentOperations": operationQueue.maxConcurrentOperationCount,
        ]
    }

    /// Performs a health check of the backup service.
    ///
    /// - Returns: Boolean indicating whether the service is healthy
    func performHealthCheck() async throws -> Bool {
        // Check if we have any active operations
        guard await backupState.isEmpty else {
            return false
        }

        // Check Restic service health
        guard try await resticService.performHealthCheck() else {
            return false
        }

        // Check keychain service health
        guard try await keychainService.performHealthCheck() else {
            return false
        }

        return true
    }

    /// Cleans up any resources that are no longer needed.
    func cleanup() async throws {
        // Clean up Restic service
        try await resticService.cleanup()

        // Clean up keychain service
        try await keychainService.cleanup()
    }

    /// Measures the execution time of an operation.
    ///
    /// - Parameters:
    ///   - name: Name of the operation being measured
    ///   - operation: The operation to measure
    /// - Returns: Result of the operation
    internal func measure<T>(
        _ name: String,
        operation: () async throws -> T
    ) async throws -> T {
        let start = Date()

        do {
            let result = try await operation()

            let duration = Date().timeIntervalSince(start)
            logger.info(
                "\(name) completed in \(String(format: "%.2f", duration))s",
                file: #file,
                function: #function,
                line: #line
            )

            return result
        } catch {
            let duration = Date().timeIntervalSince(start)
            logger.error(
                "\(name) failed after \(String(format: "%.2f", duration))s: \(error)",
                file: #file,
                function: #function,
                line: #line
            )
            throw error
        }
    }
}
