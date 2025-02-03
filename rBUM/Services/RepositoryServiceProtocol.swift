import Foundation

/// Protocol defining repository management operations
protocol RepositoryServiceProtocol {
    /// Store a repository
    /// - Parameter repository: Repository to store
    func store(_ repository: Repository) async throws
    
    /// List all repositories
    /// - Returns: Array of repositories
    func list() async throws -> [Repository]
    
    /// Delete a repository
    /// - Parameter id: ID of repository to delete
    func delete(forId id: UUID) async throws
    
    /// Check if a repository exists at the given path
    /// - Parameters:
    ///   - path: Path to check
    ///   - excludingId: Optional ID to exclude from check
    /// - Returns: True if repository exists at path
    func exists(atPath path: URL, excludingId: UUID?) async throws -> Bool
}
