import Foundation
import os.log

/// A development tool that simulates various security-related scenarios for testing purposes.
///
/// The `SecuritySimulator` provides controlled simulation of security failures and delays
/// that might occur in production environments. This allows testing of error handling
/// and timeout scenarios without waiting for actual security operations to complete.
///
/// Usage:
/// ```swift
/// let simulator = SecuritySimulator(logger: logger, configuration: config)
/// try simulator.simulateFailureIfNeeded(operation: "read", url: fileURL) { msg in
///     SecurityError.accessDenied(msg)
/// }
/// ```
@available(macOS 13.0, *)
public struct SecuritySimulator {
    private let logger: Logger
    private let configuration: DevelopmentConfiguration

    /// Initializes a new `SecuritySimulator` instance with the given logger and configuration.
    ///
    /// - Parameters:
    ///   - logger: The logger to use for logging simulated security events.
    ///   - configuration: The development configuration that controls the simulation behavior.
    public init(logger: Logger, configuration: DevelopmentConfiguration) {
        self.logger = logger
        self.configuration = configuration
    }

    /// Simulates a security failure for the given operation and URL if configured to do so.
    ///
    /// If the `shouldSimulateAccessFailures` property in the `configuration` is `true`, this
    /// method will simulate a security failure by logging an error message and throwing an
    /// error created by the given `error` closure.
    ///
    /// - Parameters:
    ///   - operation: The name of the operation that failed (e.g., "read", "write", etc.).
    ///   - url: The URL associated with the failed operation.
    ///   - error: A closure that creates an error with a given error message.
    ///
    /// - Throws: The error created by the `error` closure if simulation is enabled.
    func simulateFailureIfNeeded(
        operation: String,
        url: URL,
        error: (String) -> Error
    ) throws {
        guard configuration.shouldSimulateAccessFailures else { return }

        let errorMessage = "\(operation) failed (simulated)"
        logger.error(
            """
            Simulating \(operation) failure for URL: \
            \(url.path)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        throw error(errorMessage)
    }

    /// Simulates a delay if an artificial delay is configured.
    ///
    /// If the `artificialDelay` property in the `configuration` is greater than 0, this
    /// method will asynchronously sleep for the specified duration.
    ///
    /// - Throws: Any error that occurs during the asynchronous sleep operation.
    func simulateDelay() async throws {
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
    }
}
