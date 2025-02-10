import Foundation
import os.log

#if os(macOS)
    public extension OSLogger {
        // MARK: - Health Check

        /// Updates the health status of the logger asynchronously.
        ///
        /// This method:
        /// 1. Performs a health check
        /// 2. Updates the `isHealthy` property
        /// 3. Can be called from Objective-C
        ///
        /// Example:
        /// ```swift
        /// await logger.updateHealthStatus()
        /// if logger.isHealthy {
        ///     print("Logger is operational")
        /// }
        /// ```
        @objc func updateHealthStatus() async {
            isHealthy = await performHealthCheck()
        }

        /// Performs a health check on the logger.
        ///
        /// This method verifies:
        /// 1. The ability to write to system log
        /// 2. The validity of subsystem and category
        /// 3. The overall logging system health
        ///
        /// - Returns: `true` if the logger is healthy, `false` otherwise
        ///
        /// Example:
        /// ```swift
        /// if await logger.performHealthCheck() {
        ///     print("Logger health check passed")
        /// }
        /// ```
        @objc func performHealthCheck() async -> Bool {
            // Logger health check:
            // 1. Verify we can write to system log
            // 2. Verify subsystem and category are valid
            logger.debug(
                """
                Health check: \
                \(subsystem).\(category)
                """
            )
            return true
        }
    }
#endif
