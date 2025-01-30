//
//  CredentialsManager.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Protocol for managing repository credentials
protocol CredentialsManagerProtocol {
    /// Store credentials for a repository
    /// - Parameters:
    ///   - password: The password to store
    ///   - credentials: The repository credentials
    func storeCredentials(_ password: String, for credentials: RepositoryCredentials) async throws
    
    /// Retrieve password for a repository
    /// - Parameter credentials: The repository credentials
    /// - Returns: The stored password
    func retrievePassword(for credentials: RepositoryCredentials) async throws -> String
    
    /// Update password for a repository
    /// - Parameters:
    ///   - password: The new password
    ///   - credentials: The repository credentials
    func updatePassword(_ password: String, for credentials: RepositoryCredentials) async throws
    
    /// Delete credentials for a repository
    /// - Parameter credentials: The repository credentials to delete
    func deleteCredentials(_ credentials: RepositoryCredentials) async throws
}

/// Default implementation of CredentialsManagerProtocol using KeychainService
final class CredentialsManager: CredentialsManagerProtocol {
    private let keychainService: KeychainServiceProtocol
    
    init(keychainService: KeychainServiceProtocol) {
        self.keychainService = keychainService
    }
    
    func storeCredentials(_ password: String, for credentials: RepositoryCredentials) async throws {
        try await keychainService.storePassword(password, forService: credentials.repositoryId.uuidString, account: credentials.repositoryPath)
    }
    
    func retrievePassword(for credentials: RepositoryCredentials) async throws -> String {
        try await keychainService.retrievePassword(forService: credentials.repositoryId.uuidString, account: credentials.repositoryPath)
    }
    
    func updatePassword(_ password: String, for credentials: RepositoryCredentials) async throws {
        try await keychainService.updatePassword(password, forService: credentials.repositoryId.uuidString, account: credentials.repositoryPath)
    }
    
    func deleteCredentials(_ credentials: RepositoryCredentials) async throws {
        try await keychainService.deletePassword(forService: credentials.repositoryId.uuidString, account: credentials.repositoryPath)
    }
}
