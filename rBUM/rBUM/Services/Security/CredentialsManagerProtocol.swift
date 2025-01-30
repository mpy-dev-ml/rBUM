//
//  CredentialsManagerProtocol.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Protocol defining the interface for managing repository credentials
protocol CredentialsManagerProtocol {
    /// Store credentials for a repository
    /// - Parameter credentials: The credentials to store
    /// - Throws: KeychainError if storing fails
    func store(_ credentials: RepositoryCredentials) async throws
    
    /// Retrieve credentials for a repository
    /// - Parameter id: The repository ID
    /// - Returns: The credentials for the repository
    /// - Throws: KeychainError if retrieval fails
    func retrieve(forId id: UUID) async throws -> RepositoryCredentials
    
    /// Delete credentials for a repository
    /// - Parameter id: The repository ID
    /// - Throws: KeychainError if deletion fails
    func delete(forId id: UUID) async throws
    
    /// Get the password for a repository
    /// - Parameter id: The repository ID
    /// - Returns: The repository password
    /// - Throws: KeychainError if retrieval fails
    func getPassword(forRepositoryId id: UUID) async throws -> String
    
    /// Create new credentials for a repository
    /// - Parameters:
    ///   - id: The repository ID
    ///   - path: The repository path
    ///   - password: The repository password
    /// - Returns: The created credentials
    func createCredentials(id: UUID, path: String, password: String) -> RepositoryCredentials
}
