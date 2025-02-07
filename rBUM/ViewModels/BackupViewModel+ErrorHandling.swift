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
                "operation": .string(currentOperation?.rawValue ?? "unknown")
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
        case .missingSource(let message):
            return "Missing source: \(message)"
        case .invalidSource(let message):
            return "Invalid source: \(message)"
        case .duplicateSource(let message):
            return "Duplicate source: \(message)"
        case .missingRepository(let message):
            return "Missing repository: \(message)"
        case .invalidRepository(let message):
            return "Invalid repository: \(message)"
        case .missingCredentials(let message):
            return "Missing credentials: \(message)"
        case .invalidSettings(let message):
            return "Invalid settings: \(message)"
        case .backupFailed(let message):
            return "Backup failed: \(message)"
        }
    }
}
