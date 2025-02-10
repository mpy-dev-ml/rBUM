import Foundation

extension SnapshotListViewModel {
    // MARK: - Error Handling

    /// Handle errors that occur during snapshot operations
    /// - Parameter error: The error that occurred
    func handleError(_ error: Error) {
        logger.error(
            """
            Snapshot operation failed:
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

/// Errors that can occur during snapshot operations
enum SnapshotError: LocalizedError {
    case invalidRepository(String)
    case accessDenied(String)
    case restorationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidRepository(message):
            "Invalid repository: \(message)"
        case let .accessDenied(message):
            "Access denied: \(message)"
        case let .restorationFailed(message):
            "Restoration failed: \(message)"
        }
    }
}
