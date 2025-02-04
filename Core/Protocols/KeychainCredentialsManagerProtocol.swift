import Foundation

/// Protocol for managing repository credentials in the keychain
public protocol KeychainCredentialsManagerProtocol {
    /// Save credentials for a repository
    /// - Parameters:
    ///   - credentials: Credentials to save
    ///   - repository: Repository the credentials belong to
    /// - Throws: SecurityError if save fails
    func saveCredentials(_ credentials: RepositoryCredentials, for repository: Repository) async throws
    
    /// Get credentials for a repository
    /// - Parameter repository: Repository to get credentials for
    /// - Returns: Repository credentials
    /// - Throws: SecurityError if retrieval fails
    func getCredentials(for repository: Repository) async throws -> RepositoryCredentials
    
    /// Delete credentials for a repository
    /// - Parameter repository: Repository to delete credentials for
    /// - Throws: SecurityError if deletion fails
    func deleteCredentials(for repository: Repository) async throws
}
