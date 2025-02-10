import Foundation
import Security

public extension KeychainService {
    // MARK: - Health Check

    /// Performs a health check on the keychain service.
    ///
    /// - Returns: True if the service is healthy
    func performHealthCheck() async -> Bool {
        logger.info(
            "Performing keychain health check",
            file: #file,
            function: #function,
            line: #line
        )

        do {
            let testKey = "health_check"
            let string = "test"
            let data = Data(string.utf8)

            try save(data, for: testKey)
            try delete(for: testKey)

            logger.info(
                "Keychain health check passed",
                file: #file,
                function: #function,
                line: #line
            )
            return true
        } catch {
            logger.error(
                "Keychain health check failed: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
    }
}
