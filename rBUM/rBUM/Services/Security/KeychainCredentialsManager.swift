//
//  KeychainCredentialsManager.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import os
import Security

/// Protocol for managing secure storage of repository credentials
protocol KeychainCredentialsManagerProtocol {
    /// Store credentials securely
    func store(_ credentials: RepositoryCredentials, forRepositoryId id: String) async throws
    
    /// Retrieve credentials for a repository
    func retrieve(forId id: String) async throws -> RepositoryCredentials
    
    /// Delete credentials for a repository
    func delete(forId id: String) async throws
    
    /// List all stored credentials
    func list() async throws -> [(repositoryId: String, credentials: RepositoryCredentials)]
}

/// Implementation of KeychainCredentialsManagerProtocol that uses the macOS Keychain for secure storage
final class KeychainCredentialsManager: KeychainCredentialsManagerProtocol {
    private let keychainService: KeychainServiceProtocol
    private let credentialsStorage: CredentialsStorageProtocol
    private let logger: Logger
    private let serviceName = "dev.mpy.rBUM.repository"
    
    init(
        keychainService: KeychainServiceProtocol = KeychainService(),
        credentialsStorage: CredentialsStorageProtocol = CredentialsStorage()
    ) {
        self.keychainService = keychainService
        self.credentialsStorage = credentialsStorage
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.mpy.rBUM",
                           category: "Keychain")
    }
    
    func store(_ credentials: RepositoryCredentials, forRepositoryId id: String) async throws {
        do {
            // Store password in keychain
            try await keychainService.storePassword(
                credentials.password,
                service: "\(serviceName).\(id)",
                account: credentials.repositoryPath
            )
            logger.info("Saved password to keychain for repository: \(id, privacy: .private)")
            
            // Store credentials metadata
            try credentialsStorage.store(credentials, forRepositoryId: id)
            
            logger.info("Stored credentials for repository: \(id, privacy: .private)")
        } catch {
            logger.error("Failed to store credentials: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    
    func retrieve(forId id: String) async throws -> RepositoryCredentials {
        do {
            // Verify credentials metadata exists
            guard let credentials = try credentialsStorage.retrieve(forRepositoryId: id) else {
                logger.error("Credentials not found for repository: \(id, privacy: .private)")
                throw CredentialsError.notFound
            }
            
            // Retrieve password from keychain
            let password = try await keychainService.retrievePassword(
                service: "\(serviceName).\(id)",
                account: credentials.repositoryPath
            )
            
            // Create new credentials with retrieved password
            let updatedCredentials = RepositoryCredentials(
                repositoryPath: credentials.repositoryPath,
                password: password
            )
            
            logger.info("Retrieved credentials for repository: \(id, privacy: .private)")
            return updatedCredentials
        } catch {
            logger.error("Failed to retrieve credentials: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    
    func delete(forId id: String) async throws {
        do {
            // Get credentials to get repository path
            guard let credentials = try credentialsStorage.retrieve(forRepositoryId: id) else {
                logger.error("Credentials not found for repository: \(id, privacy: .private)")
                throw CredentialsError.notFound
            }
            
            // Delete from keychain
            try await keychainService.deletePassword(
                service: "\(serviceName).\(id)",
                account: credentials.repositoryPath
            )
            
            // Delete metadata
            try credentialsStorage.delete(forRepositoryId: id)
            
            logger.info("Deleted credentials for repository: \(id, privacy: .private)")
        } catch {
            logger.error("Failed to delete credentials: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    
    func list() async throws -> [(repositoryId: String, credentials: RepositoryCredentials)] {
        do {
            let storedCredentials = try credentialsStorage.list()
            
            // For each stored credential, retrieve its password from keychain
            return try await withThrowingTaskGroup(of: (String, RepositoryCredentials).self) { group in
                for (repositoryId, storedCredentials) in storedCredentials {
                    group.addTask {
                        let password = try await self.keychainService.retrievePassword(
                            service: "\(self.serviceName).\(repositoryId)",
                            account: storedCredentials.repositoryPath
                        )
                        
                        let credentials = RepositoryCredentials(
                            repositoryPath: storedCredentials.repositoryPath,
                            password: password
                        )
                        
                        return (repositoryId, credentials)
                    }
                }
                
                var results: [(String, RepositoryCredentials)] = []
                for try await result in group {
                    results.append(result)
                }
                
                return results
            }
        } catch {
            logger.error("Failed to list credentials: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

/// Errors specific to credentials operations
enum CredentialsError: LocalizedError {
    case notFound
    case invalidData
    case keychainError(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Credentials not found"
        case .invalidData:
            return "Invalid credentials data"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        }
    }
}
