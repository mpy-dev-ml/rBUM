import Foundation

extension DevelopmentKeychainService {
    /// Tracks metrics for keychain operations
    private struct KeychainMetrics {
        private(set) var saveCount: Int = 0
        private(set) var retrievalCount: Int = 0
        private(set) var deleteCount: Int = 0
        private(set) var failureCount: Int = 0
        private(set) var accessGroupConfigCount: Int = 0
        private(set) var accessValidationCount: Int = 0

        mutating func recordSave() {
            saveCount += 1
        }

        mutating func recordRetrieval() {
            retrievalCount += 1
        }

        mutating func recordDelete() {
            deleteCount += 1
        }

        mutating func recordFailure(operation: String) {
            failureCount += 1
        }

        mutating func recordAccessGroupConfig() {
            accessGroupConfigCount += 1
        }

        mutating func recordAccessValidation() {
            accessValidationCount += 1
        }
    }
}
