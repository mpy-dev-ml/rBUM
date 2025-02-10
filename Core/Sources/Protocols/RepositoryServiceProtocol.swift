import Foundation

/// Protocol for managing repositories
public protocol RepositoryServiceProtocol {
    /// Create a new repository
    /// - Parameter repository: Repository to create
    /// - Throws: RepositoryError if creation fails
    func createRepository(
        _ repository: Repository
    ) async throws

    /// List all repositories
    /// - Returns: Array of repositories
    /// - Throws: RepositoryError if listing fails
    func listRepositories() async throws -> [Repository]

    /// Delete a repository
    /// - Parameter repository: Repository to delete
    /// - Throws: RepositoryError if deletion fails
    func deleteRepository(
        _ repository: Repository
    ) async throws

    /// Update repository information
    /// - Parameter repository: Repository to update
    /// - Throws: RepositoryError if update fails
    func updateRepository(
        _ repository: Repository
    ) async throws
}

/// Error types for repository operations
public enum RepositoryError: LocalizedError {
    case creationFailed(String)
    case deletionFailed(String)
    case updateFailed(String)
    case listingFailed(String)
    case invalidConfiguration

    public var errorDescription: String? {
        switch self {
        case let .creationFailed(reason):
            "Failed to create repository: \(reason)"
        case let .deletionFailed(reason):
            "Failed to delete repository: \(reason)"
        case let .updateFailed(reason):
            "Failed to update repository: \(reason)"
        case let .listingFailed(reason):
            "Failed to list repositories: \(reason)"
        case .invalidConfiguration:
            "Invalid repository configuration"
        }
    }
}
