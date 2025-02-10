import Core
import Foundation

extension BackupViewModel {
    // MARK: - Error Handling

    /// Handle errors that occur during backup operations
    /// - Parameter error: The error that occurred
    func handleError(_ error: Error) {
        logger.error(
            """
            Backup operation failed:
            Error: \(error.localizedDescription)
            Operation: \(currentOperation?.rawValue ?? "unknown")
            """,
            metadata: [
                "error": .string("\(error)"),
                "operation": .string(currentOperation?.rawValue ?? "unknown"),
            ]
        )

        self.error = error
        showError = true
        progress = nil
        currentOperation = nil
    }

    /// Clear the current error state
    func clearError() {
        error = nil
        showError = false
    }
}

// MARK: - Error Types

/// Errors that can occur during backup operations
enum BackupError: LocalizedError {
    case missingSource(String)
    case invalidSource(String)
    case duplicateSource(String)
    case missingRepository(String)
    case invalidRepository(String)
    case missingCredentials(String)
    case invalidSettings(String)
    case backupFailed(String)

    var errorDescription: String? {
        switch self {
        case let .missingSource(message):
            "Missing source: \(message)"
        case let .invalidSource(message):
            "Invalid source: \(message)"
        case let .duplicateSource(message):
            "Duplicate source: \(message)"
        case let .missingRepository(message):
            "Missing repository: \(message)"
        case let .invalidRepository(message):
            "Invalid repository: \(message)"
        case let .missingCredentials(message):
            "Missing credentials: \(message)"
        case let .invalidSettings(message):
            "Invalid settings: \(message)"
        case let .backupFailed(message):
            "Backup failed: \(message)"
        }
    }
}
