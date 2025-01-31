import Foundation
@testable import rBUM

/// Mock implementation of RepositoryService for testing
final class MockRepositoryService: RepositoryServiceProtocol {
    private var repositories: [Repository] = []
    private var error: Error?
    
    /// Reset mock to initial state
    func reset() {
        repositories = []
        error = nil
    }
    
    /// Set an error to be thrown by operations
    func setError(_ error: Error) {
        self.error = error
    }
    
    // MARK: - Protocol Implementation
    
    func store(_ repository: Repository) throws {
        if let error = error { throw error }
        repositories.append(repository)
    }
    
    func list() throws -> [Repository] {
        if let error = error { throw error }
        return repositories
    }
    
    func delete(forId id: UUID) throws {
        if let error = error { throw error }
        repositories.removeAll { $0.id == id }
    }
    
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool {
        if let error = error { throw error }
        return repositories.contains { repository in
            repository.path == path && repository.id != excludingId
        }
    }
}
