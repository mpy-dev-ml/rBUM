//
//  RepositoryCredentials.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Represents the credentials for a Restic repository
struct RepositoryCredentials: Codable {
    /// Unique identifier for the repository these credentials belong to
    let repositoryId: UUID
    
    /// Path to the repository, used as the account identifier in Keychain
    let repositoryPath: String
    
    /// Optional name of the key file if using key-based authentication
    var keyFileName: String?
    
    /// Creation date of these credentials
    let createdAt: Date
    
    /// Last time these credentials were modified
    var modifiedAt: Date
    
    /// Service name used for Keychain storage
    var keychainService: String {
        "dev.mpy.rBUM.repository.\(repositoryId.uuidString)"
    }
    
    /// Account name used for Keychain storage
    var keychainAccount: String {
        repositoryPath
    }
    
    init(repositoryId: UUID, repositoryPath: String, keyFileName: String? = nil) {
        self.repositoryId = repositoryId
        self.repositoryPath = repositoryPath
        self.keyFileName = keyFileName
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

// MARK: - Equatable
extension RepositoryCredentials: Equatable {
    static func == (lhs: RepositoryCredentials, rhs: RepositoryCredentials) -> Bool {
        // Only compare the identifying properties, not timestamps
        lhs.repositoryId == rhs.repositoryId &&
        lhs.repositoryPath == rhs.repositoryPath &&
        lhs.keyFileName == rhs.keyFileName
    }
}

/// Protocol for managing repository credentials
protocol RepositoryCredentialsManager {
    /// Store credentials for a repository
    /// - Parameters:
    ///   - password: The repository password
    ///   - credentials: The repository credentials
    func storeCredentials(_ password: String, for credentials: RepositoryCredentials) async throws
    
    /// Retrieve password for a repository
    /// - Parameter credentials: The repository credentials
    /// - Returns: The repository password
    func retrievePassword(for credentials: RepositoryCredentials) async throws -> String
    
    /// Update password for a repository
    /// - Parameters:
    ///   - password: The new password
    ///   - credentials: The repository credentials
    func updatePassword(_ password: String, for credentials: RepositoryCredentials) async throws
    
    /// Delete credentials for a repository
    /// - Parameter credentials: The repository credentials
    func deleteCredentials(_ credentials: RepositoryCredentials) async throws
}

/// Manages repository credentials using the Keychain service
final class KeychainCredentialsManager: RepositoryCredentialsManager {
    private let keychainService: KeychainServiceProtocol
    
    init(keychainService: KeychainServiceProtocol) {
        self.keychainService = keychainService
    }
    
    func storeCredentials(_ password: String, for credentials: RepositoryCredentials) async throws {
        try await keychainService.storePassword(
            password,
            forService: credentials.keychainService,
            account: credentials.keychainAccount
        )
    }
    
    func retrievePassword(for credentials: RepositoryCredentials) async throws -> String {
        try await keychainService.retrievePassword(
            forService: credentials.keychainService,
            account: credentials.keychainAccount
        )
    }
    
    func updatePassword(_ password: String, for credentials: RepositoryCredentials) async throws {
        try await keychainService.updatePassword(
            password,
            forService: credentials.keychainService,
            account: credentials.keychainAccount
        )
    }
    
    func deleteCredentials(_ credentials: RepositoryCredentials) async throws {
        try await keychainService.deletePassword(
            forService: credentials.keychainService,
            account: credentials.keychainAccount
        )
    }
}
