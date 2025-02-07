import Foundation
import os.log

/// Simulates security failures and delays
@available(macOS 13.0, *)
public struct SecuritySimulator {
    private let logger: Logger
    private let configuration: DevelopmentConfiguration
    
    public init(logger: Logger, configuration: DevelopmentConfiguration) {
        self.logger = logger
        self.configuration = configuration
    }
    
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
    
    func simulateDelay() async throws {
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
    }
}
