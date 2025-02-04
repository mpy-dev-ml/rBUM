import Foundation

/// Protocol for creating and initializing repositories
public protocol RepositoryCreationServiceProtocol {
    /// Create a new repository at the specified URL
    /// - Parameters:
    ///   - url: Location for the new repository
    ///   - credentials: Credentials for repository access
    /// - Returns: The newly created repository
    /// - Throws: SecurityError if creation fails
    func createRepository(at url: URL, credentials: RepositoryCredentials) async throws -> Repository
}
