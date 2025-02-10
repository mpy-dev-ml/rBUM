import Core
import Foundation
import os.log

extension RepositoryListViewModel {
    /// Enumeration of repository operation types
    enum RepositoryOperationType {
        case load
        case refresh
        case delete
    }

    func handleRepositoryOperation(
        type: RepositoryOperationType,
        repository: Repository? = nil
    ) async throws {
        let operationId = UUID()

        do {
            // Start operation
            try await startRepositoryOperation(operationId, type: type, repository: repository)

            // Validate prerequisites
            try await validateRepositoryPrerequisites(type: type, repository: repository)

            // Execute operation
            try await executeRepositoryOperation(type: type, repository: repository)

            // Complete operation
            try await completeRepositoryOperation(operationId, success: true)

        } catch {
            // Handle failure
            try await completeRepositoryOperation(operationId, success: false, error: error)
            throw error
        }
    }

    private func startRepositoryOperation(
        _ id: UUID,
        type: RepositoryOperationType,
        repository: Repository?
    ) async throws {
        // Record operation start
        let operation = RepositoryOperation(
            id: id,
            type: type,
            repository: repository,
            timestamp: Date(),
            status: .inProgress
        )
        // operationRecorder.recordOperation(operation)

        // Log operation start
        logger.info("Starting repository operation", metadata: [
            "operation": .string(id.uuidString),
            "type": .string(type.rawValue),
            "repository": repository.map { .string($0.id.uuidString) } ?? .string("none"),
        ])
    }

    private func validateRepositoryPrerequisites(
        type: RepositoryOperationType,
        repository: Repository?
    ) async throws {
        switch type {
        case .load:
            try await validateLoadPrerequisites()
        case .refresh:
            try await validateRefreshPrerequisites()
        case .delete:
            try await validateDeletePrerequisites(repository)
        }
    }

    private func validateLoadPrerequisites() async throws {
        // Check storage access
        guard try await hasStorageAccess() else {
            throw RepositoryUIError.accessDenied("Cannot access repository storage")
        }
    }

    private func validateRefreshPrerequisites() async throws {
        // Check storage access
        guard try await hasStorageAccess() else {
            throw RepositoryUIError.accessDenied("Cannot access repository storage")
        }
    }

    private func validateDeletePrerequisites(_ repository: Repository?) async throws {
        // Check storage access
        guard try await hasStorageAccess() else {
            throw RepositoryUIError.accessDenied("Cannot access repository storage")
        }

        // Ensure repository exists
        guard let repository else {
            throw RepositoryUIError.invalidOperation("No repository specified for deletion")
        }
    }

    private func executeRepositoryOperation(
        type: RepositoryOperationType,
        repository: Repository?
    ) async throws {
        switch type {
        case .load:
            try await executeLoadOperation()
        case .refresh:
            try await executeRefreshOperation()
        case .delete:
            guard let repository else {
                throw RepositoryUIError.invalidOperation("No repository specified for deletion")
            }
            try await executeDeleteOperation(repository)
        }
    }

    private func completeRepositoryOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async throws {
        // Update operation status
        let status: RepositoryOperationStatus = success ? .completed : .failed

        // Log completion
        logger.info("Completed repository operation", metadata: [
            "operation": .string(id.uuidString),
            "success": .string(success ? "true" : "false"),
            "error": error.map { .string($0.localizedDescription) } ?? .string("none"),
        ])
    }
}
