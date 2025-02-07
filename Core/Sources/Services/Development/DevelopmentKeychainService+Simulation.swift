import Foundation

extension DevelopmentKeychainService {
    // MARK: - Failure Simulation

    /// Simulates keychain operation failures for testing error handling
    func simulateFailureIfNeeded(
        operation: String,
        error: Error
    ) throws {
        guard let failureRate = simulatedFailureRates[operation] else {
            return
        }

        let random = Double.random(in: 0...1)
        if random < failureRate {
            throw error
        }
    }

    /// Sets the failure rate for a specific operation
    /// - Parameters:
    ///   - rate: Failure rate between 0 and 1
    ///   - operation: Operation to simulate failures for
    func setFailureRate(_ rate: Double, for operation: String) {
        simulatedFailureRates[operation] = rate
    }

    /// Resets all simulated failure rates
    func resetFailureRates() {
        simulatedFailureRates.removeAll()
    }
}
