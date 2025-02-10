import Foundation

/// Circuit breaker implementation of ResticXPCServiceProtocol used specifically to break
/// circular dependencies during initialization. This is a minimal implementation that
/// should never be used in production code paths.
///
/// Usage:
/// - During initialization where a temporary XPC service is needed
/// - In dependency injection containers to break circular references
/// - As a placeholder until the real XPC service is ready
///
/// Warning: This service logs warnings if called and should never be used in production code paths.
final class CircuitBreakerXPCService: NSObject, ResticXPCServiceProtocol {
    // MARK: - Properties

    private let logger: LoggerProtocol
    public private(set) var isHealthy: Bool = false

    // MARK: - Initialization

    init(logger: LoggerProtocol) {
        self.logger = logger
        super.init()
    }

    // MARK: - HealthCheckable Implementation

    @objc public func performHealthCheck() async throws -> Bool {
        logger.warning(
            "Circuit breaker XPC service health check called - this should not happen in production",
            file: #file,
            function: #function,
            line: #line
        )
        return false
    }

    @objc public func updateHealthStatus() async {
        logger.warning(
            "Circuit breaker XPC service called - this should not happen in production",
            file: #file,
            function: #function,
            line: #line
        )
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

    // MARK: - ResticXPCServiceProtocol Implementation

    @objc func ping() async -> Bool {
        logger.warning(
            "Circuit breaker XPC service called - this should not happen in production",
            file: #file,
            function: #function,
            line: #line
        )
        return false
    }

    @objc func initializeRepository(at _: URL, username _: String, password _: String) async throws {
        logger.warning(
            "Circuit breaker XPC service called - this should not happen in production",
            file: #file,
            function: #function,
            line: #line
        )
        throw ServiceError.operationFailed
    }

    @objc func backup(from _: URL, to _: URL, username _: String, password _: String) async throws {
        logger.warning(
            "Circuit breaker XPC service called - this should not happen in production",
            file: #file,
            function: #function,
            line: #line
        )
        throw ServiceError.operationFailed
    }

    @objc func listSnapshots(username _: String, password _: String) async throws -> [String] {
        logger.warning(
            "Circuit breaker XPC service called - this should not happen in production",
            file: #file,
            function: #function,
            line: #line
        )
        throw ServiceError.operationFailed
    }

    @objc func restore(from _: URL, to _: URL, username _: String, password _: String) async throws {
        logger.warning(
            "Circuit breaker XPC service called - this should not happen in production",
            file: #file,
            function: #function,
            line: #line
        )
        throw ServiceError.operationFailed
    }
}
