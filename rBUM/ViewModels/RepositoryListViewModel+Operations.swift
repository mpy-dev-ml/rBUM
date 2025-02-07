import Core
import Foundation

extension RepositoryListViewModel {
    // MARK: - Repository Operations

    enum RepositoryOperationType: String {
        case load = "Loading"
        case refresh = "Refreshing"
        case delete = "Deleting"
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
            "repository": repository.map { .string($0.id.uuidString) } ?? .string("none")
        ])
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
            if let repository = repository {
                try await executeDeleteOperation(repository)
            }
        }
    }
    
    private func executeLoadOperation() async throws {
        // Load repositories from storage
        let repositories = try await repositoryService.listRepositories()
        
        // Update repositories
        await updateRepositories(repositories)
        
        // Load repository details
        try await loadRepositoryDetails(for: repositories)
    }
    
    private func executeRefreshOperation() async throws {
        // Refresh repository list
        let repositories = try await repositoryService.listRepositories()
        
        // Update repositories
        await updateRepositories(repositories)
        
        // Refresh repository details
        try await refreshRepositoryDetails(for: repositories)
    }
    
    private func executeDeleteOperation(_ repository: Repository) async throws {
        // Delete repository files
        try await deleteRepositoryFiles(repository)
        
        // Delete repository from storage
        try await deleteRepositoryFromStorage(repository)
        
        // Remove repository from list
        await removeRepository(repository)
    }
    
    private func completeRepositoryOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async throws {
        // Update operation status
        // operationRecorder.updateOperation(id, status: status, error: error)
        
        // Log completion
        logger.info("Completed repository operation", metadata: [
            "operation": .string(id.uuidString),
            "status": .string(success ? "completed" : "failed"),
            "error": error.map { .string($0.localizedDescription) } ?? .string("none")
        ])
    }
}
