import Foundation
import os.log

/// Configuration for development and testing environments
@objc public class DevelopmentConfiguration: NSObject {
    /// Whether to simulate access failures for testing error handling
    @objc public var shouldSimulateAccessFailures: Bool

    /// Artificial delay in seconds to simulate network latency
    @objc public var artificialDelay: Double

    /// Whether to enable verbose logging
    @objc public var verboseLogging: Bool

    /// Whether to enable security operation recording
    @objc public var recordOperations: Bool

    @objc public init(
        shouldSimulateAccessFailures: Bool = false,
        artificialDelay: Double = 0.0,
        verboseLogging: Bool = false,
        recordOperations: Bool = true
    ) {
        self.shouldSimulateAccessFailures = shouldSimulateAccessFailures
        self.artificialDelay = artificialDelay
        self.verboseLogging = verboseLogging
        self.recordOperations = recordOperations
        super.init()
    }
}
