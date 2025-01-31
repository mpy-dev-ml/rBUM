import Foundation
@testable import rBUM

/// Mock implementation of CredentialsManager for testing
final class MockCredentialsManager: CredentialsManagerProtocol {
    private var credentials: [UUID: RepositoryCredentials] = [:]
    private var error: Error?
    
    /// Reset mock to initial state
    func reset() {
        credentials = [:]
        error = nil
    }
    
    /// Set an error to be thrown by operations
    func setError(_ error: Error) {
        self.error = error
    }
    
    // MARK: - Protocol Implementation
    
    func store(_ credentials: RepositoryCredentials) async throws {
        if let error = error { throw error }
        self.credentials[credentials.repositoryId] = credentials
    }
    
    func retrieve(forId id: UUID) async throws -> RepositoryCredentials {
        if let error = error { throw error }
        guard let credentials = credentials[id] else {
            throw CredentialsError.notFound
        }
        return credentials
    }
    
    func update(_ credentials: RepositoryCredentials) async throws {
        if let error = error { throw error }
        guard self.credentials[credentials.repositoryId] != nil else {
            throw CredentialsError.notFound
        }
        self.credentials[credentials.repositoryId] = credentials
    }
    
    func delete(forId id: UUID) async throws {
        if let error = error { throw error }
        guard credentials[id] != nil else {
            throw CredentialsError.notFound
        }
        credentials.removeValue(forKey: id)
    }
    
    func getPassword(forRepositoryId id: UUID) async throws -> String {
        if let error = error { throw error }
        guard let credentials = credentials[id] else {
            throw CredentialsError.notFound
        }
        return credentials.password
    }
    
    func createCredentials(id: UUID, path: String, password: String) -> RepositoryCredentials {
        RepositoryCredentials(
            repositoryId: id,
            password: password,
            repositoryPath: path
        )
    }
}
