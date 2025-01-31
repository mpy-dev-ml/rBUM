//
//  KeychainCredentialsManager.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import os
import Security

/// Implementation of CredentialsManagerProtocol that uses the macOS Keychain for secure storage
final class KeychainCredentialsManager: CredentialsManagerProtocol {
    private let keychainService: KeychainServiceProtocol
    private let credentialsStorage: CredentialsStorageProtocol
    private let logger: Logger
    
    init(
        keychainService: KeychainServiceProtocol = KeychainService(),
        credentialsStorage: CredentialsStorageProtocol = CredentialsStorage(),
        logger: Logger = Logger(subsystem: "dev.mpy.rBUM", category: "Keychain")
    ) {
        self.keychainService = keychainService
        self.credentialsStorage = credentialsStorage
        self.logger = logger
    }
    
    func store(_ credentials: RepositoryCredentials) async throws {
        do {
            // Store password in keychain
            try await keychainService.storePassword(
                credentials.password,
                service: credentials.keychainService,
                account: credentials.keychainAccount
            )
            logger.info("Successfully saved password to keychain")
            
            // Store credentials metadata
            try credentialsStorage.store(credentials)
            
            logger.info("Stored credentials for repository: \(credentials.repositoryId)")
        } catch {
            logger.error("Failed to store credentials: \(error.localizedDescription)")
            throw error
        }
    }
    
    func retrieve(forId id: UUID) async throws -> RepositoryCredentials {
        do {
            // Verify credentials metadata exists
            guard let credentials = try credentialsStorage.retrieve(forRepositoryId: id) else {
                throw CredentialsError.notFound
            }
            
            // Retrieve password from keychain
            let password = try await keychainService.retrievePassword(
                service: credentials.keychainService,
                account: credentials.keychainAccount
            )
            logger.info("Successfully retrieved password from keychain")
            
            // Create new credentials with retrieved password
            return RepositoryCredentials(
                repositoryId: credentials.repositoryId,
                password: password,
                repositoryPath: credentials.repositoryPath,
                keyFileName: credentials.keyFileName
            )
        } catch {
            logger.error("Failed to retrieve credentials: \(error.localizedDescription)")
            throw error
        }
    }
    
    func update(_ credentials: RepositoryCredentials) async throws {
        do {
            // Retrieve existing credentials metadata
            guard let existingCredentials = try credentialsStorage.retrieve(forRepositoryId: credentials.repositoryId) else {
                throw CredentialsError.notFound
            }
            
            // Update password in keychain
            try await keychainService.updatePassword(
                credentials.password,
                service: existingCredentials.keychainService,
                account: existingCredentials.keychainAccount
            )
            logger.info("Successfully updated password in keychain")
            
            // Update credentials metadata
            try credentialsStorage.update(credentials)
            
            logger.info("Updated credentials for repository: \(credentials.repositoryId)")
        } catch {
            logger.error("Failed to update credentials: \(error.localizedDescription)")
            throw error
        }
    }
    
    func delete(forId id: UUID) async throws {
        do {
            // Retrieve credentials metadata
            guard let credentials = try credentialsStorage.retrieve(forRepositoryId: id) else {
                throw CredentialsError.notFound
            }
            
            // Delete password from keychain
            try await keychainService.deletePassword(
                service: credentials.keychainService,
                account: credentials.keychainAccount
            )
            logger.info("Successfully deleted password from keychain")
            
            // Delete credentials metadata
            try credentialsStorage.delete(forRepositoryId: id)
            
            logger.info("Deleted credentials for repository: \(id)")
        } catch {
            logger.error("Failed to delete credentials: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getPassword(forRepositoryId id: UUID) async throws -> String {
        // Get metadata
        guard let credentials = try credentialsStorage.retrieve(forRepositoryId: id) else {
            throw KeychainError.itemNotFound
        }
        
        // Get password from Keychain
        return try await keychainService.retrievePassword(
            service: credentials.keychainService,
            account: credentials.repositoryPath
        )
    }
    
    func createCredentials(id: UUID, path: String, password: String) -> RepositoryCredentials {
        RepositoryCredentials(
            repositoryId: id,
            password: password,
            repositoryPath: path
        )
    }
}

/// Errors specific to credentials operations
enum CredentialsError: LocalizedError {
    case notFound
    case invalidPassword
    case storeFailed(String)
    case retrieveFailed(String)
    case deleteFailed(String)
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Credentials not found"
        case .invalidPassword:
            return "Invalid password"
        case .storeFailed(let reason):
            return "Failed to store credentials: \(reason)"
        case .retrieveFailed(let reason):
            return "Failed to retrieve credentials: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete credentials: \(reason)"
        case .updateFailed(let reason):
            return "Failed to update credentials: \(reason)"
        }
    }
}
