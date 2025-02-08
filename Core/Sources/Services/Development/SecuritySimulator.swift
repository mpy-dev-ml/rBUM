import Foundation
import os.log

/// Simulates security-related behaviors for development and testing
@available(macOS 13.0, *)
@objc public final class SecuritySimulator: NSObject {
    private let logger: Logger
    private let configuration: DevelopmentConfiguration

    @objc public init(logger: Logger, configuration: DevelopmentConfiguration) {
        self.logger = logger
        self.configuration = configuration
        super.init()
    }

    @objc public func simulateFailure(
        operation: String,
        url: URL
    ) throws -> NSError {
        guard configuration.shouldSimulateAccessFailures else {
            throw NSError(domain: "dev.mpy.rbum.security", code: 0, userInfo: nil)
        }

        let errorMessage = "\(operation) failed (simulated)"
        logger.error("""
                     Simulating \(operation) failure for URL: \
                     \(url.path)
                     """,
                     file: #file,
                     function: #function,
                     line: #line)
        
        return NSError(
            domain: "dev.mpy.rbum.security",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: errorMessage]
        )
    }

    @objc public func simulateDelay() async throws {
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
    }
}
