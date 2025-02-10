import Foundation

@available(macOS 13.0, *)
extension ResticXPCService {
    // MARK: - Operation Types

    /// Represents a pending Restic XPC operation
    struct ResticXPCOperation: Identifiable {
        let id: UUID
        let type: OperationType
        let startTime: Date
        var status: OperationStatus
        var progress: Double
        var error: Error?

        init(type: OperationType) {
            id = UUID()
            self.type = type
            startTime = Date()
            status = .pending
            progress = 0.0
        }
    }

    /// Types of operations that can be performed
    enum OperationType {
        case backup(source: URL, destination: URL)
        case restore(source: URL, destination: URL)
        case initialize(url: URL)
        case list
        case check
        case prune

        var description: String {
            switch self {
            case let .backup(source, destination):
                "Backup from \(source.path) to \(destination.path)"
            case let .restore(source, destination):
                "Restore from \(source.path) to \(destination.path)"
            case let .initialize(url):
                "Initialize repository at \(url.path)"
            case .list:
                "List snapshots"
            case .check:
                "Check repository"
            case .prune:
                "Prune repository"
            }
        }
    }

    /// Status of an operation
    enum OperationStatus {
        case pending
        case running
        case completed
        case failed
        case cancelled
    }

    // MARK: - Operation Management

    /// Start tracking a new operation
    /// - Parameter type: Type of operation to track
    /// - Returns: ID of the new operation
    func startOperation(_ type: OperationType) -> UUID {
        let operation = ResticXPCOperation(type: type)
        queue.sync {
            pendingOperations.append(operation)
        }
        logger.info(
            "Started operation: \(type.description)",
            file: #file,
            function: #function,
            line: #line
        )
        return operation.id
    }

    /// Update the status of an operation
    /// - Parameters:
    ///   - id: Operation ID
    ///   - status: New status
    ///   - error: Optional error if operation failed
    func updateOperation(_ id: UUID, status: OperationStatus, error: Error? = nil) {
        queue.sync {
            if let index = pendingOperations.firstIndex(where: { $op in op.id == id }) {
                pendingOperations[index].status = status
                pendingOperations[index].error = error

                logger.info(
                    "Updated operation \(id): \(status)",
                    file: #file,
                    function: #function,
                    line: #line
                )

                if status == .completed || status == .failed || status == .cancelled {
                    cleanupOperation(id)
                }
            }
        }
    }

    /// Update the progress of an operation
    /// - Parameters:
    ///   - id: Operation ID
    ///   - progress: Progress value between 0 and 1
    func updateOperationProgress(_ id: UUID, progress: Double) {
        queue.sync {
            if let index = pendingOperations.firstIndex(where: { $op in op.id == id }) {
                pendingOperations[index].progress = progress
            }
        }
    }

    /// Cancel an operation
    /// - Parameter id: Operation ID
    func cancelOperation(_ id: UUID) {
        queue.sync {
            if let index = pendingOperations.firstIndex(where: { $op in op.id == id }) {
                pendingOperations[index].status = .cancelled
                cleanupOperation(id)
            }
        }
    }

    /// Get the status of an operation
    /// - Parameter id: Operation ID
    /// - Returns: Current operation status and progress
    func getOperationStatus(_ id: UUID) -> (status: OperationStatus, progress: Double)? {
        queue.sync {
            if let operation = pendingOperations.first(where: { $op in op.id == id }) {
                return (operation.status, operation.progress)
            }
            return nil
        }
    }

    /// Clean up resources for an operation
    /// - Parameter id: Operation ID
    private func cleanupOperation(_ id: UUID) {
        queue.sync {
            pendingOperations.removeAll { $op in op.id == id }
        }
    }
}
