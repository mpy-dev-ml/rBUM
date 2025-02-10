import Foundation

// MARK: - HealthCheck Extension

@available(macOS 13.0, *)
public extension DevelopmentBookmarkService {
    /// Check the health status of the bookmark service
    func checkHealth() async throws -> HealthStatus {
        let status = withThreadSafety {
            HealthStatus(
                isHealthy: true,
                details: [
                    "total_bookmarks": "\(metrics.totalBookmarks)",
                    "total_validations": "\(metrics.totalValidations)",
                    "total_accesses": "\(metrics.totalAccesses)",
                    "failed_validations": "\(metrics.failedValidations)",
                    "failed_accesses": "\(metrics.failedAccesses)",
                    "avg_validation_time": String(format: "%.3f", metrics.averageValidationTime),
                    "avg_access_time": String(format: "%.3f", metrics.averageAccessTime),
                    "memory_usage": "\(metrics.resourceUsage.memoryUsage)",
                    "disk_usage": "\(metrics.resourceUsage.diskUsage)",
                    "cpu_usage": String(format: "%.1f", metrics.resourceUsage.cpuUsage),
                ]
            )
        }

        logger.debug("Health check completed", metadata: [
            "status": "\(status.isHealthy)",
            "details": "\(status.details)",
        ])

        return status
    }
}
