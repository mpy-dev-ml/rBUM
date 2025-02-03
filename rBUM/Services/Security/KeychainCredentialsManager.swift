//
//  KeychainCredentialsManager.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Protocol for managing secure storage of repository credentials
public protocol KeychainCredentialsManagerProtocol {
    /// Store credentials securely
    /// - Parameters:
    ///   - credentials: The credentials to store
    ///   - id: The repository ID
    /// - Throws: CredentialsError if storage fails
    func store(_ credentials: RepositoryCredentials, forRepositoryId id: String) async throws
    
    /// Retrieve credentials for a repository
    /// - Parameter id: The repository ID
    /// - Returns: The stored credentials
    /// - Throws: CredentialsError if retrieval fails
    func retrieve(forId id: String) async throws -> RepositoryCredentials
    
    /// Delete credentials for a repository
    /// - Parameter id: The repository ID
    /// - Throws: CredentialsError if deletion fails
    func delete(forId id: String) async throws
    
    /// List all stored credentials
    /// - Returns: Array of tuples containing repository IDs and their credentials
    /// - Throws: CredentialsError if listing fails
    func list() async throws -> [(repositoryId: String, credentials: RepositoryCredentials)]
}

/// Implementation of KeychainCredentialsManagerProtocol that uses the macOS Keychain for secure storage
final class KeychainCredentialsManager: KeychainCredentialsManagerProtocol {
    private let logger: LoggerProtocol
    private let securityService: SecurityServiceProtocol
    private let dateProvider: DateProviderProtocol
    private let notificationCenter: NotificationCenterProtocol
    private let serviceName: String
    
    init(
        logger: LoggerProtocol = Logging.logger(for: .security),
        securityService: SecurityServiceProtocol = SecurityService(),
        dateProvider: DateProviderProtocol = DateProvider(),
        notificationCenter: NotificationCenterProtocol = NotificationCenter.default,
        serviceName: String = "dev.mpy.rBUM.repository"
    ) {
        self.logger = logger
        self.securityService = securityService
        self.dateProvider = dateProvider
        self.notificationCenter = notificationCenter
        self.serviceName = serviceName
        
        logger.debug("Initialized KeychainCredentialsManager", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    func store(_ credentials: RepositoryCredentials, forRepositoryId id: String) async throws {
        logger.info("Storing credentials for repository: \(id)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Store password in keychain
            try await securityService.storePassword(
                credentials.password,
                service: "\(serviceName).\(id)",
                account: credentials.repositoryPath
            )
            
            // Post notification
            notificationCenter.post(
                name: .credentialsStored,
                object: self,
                userInfo: ["repository": id]
            )
            
            logger.info("Successfully stored credentials", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to store credentials: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
    
    func retrieve(forId id: String) async throws -> RepositoryCredentials {
        logger.info("Retrieving credentials for repository: \(id)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Retrieve password from keychain
            let password = try await securityService.retrievePassword(
                service: "\(serviceName).\(id)",
                account: id
            )
            
            // Create credentials
            let credentials = RepositoryCredentials(password: password)
            
            logger.info("Successfully retrieved credentials", privacy: .public, file: #file, function: #function, line: #line)
            return credentials
        } catch {
            logger.error("Failed to retrieve credentials: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
    
    func delete(forId id: String) async throws {
        logger.info("Deleting credentials for repository: \(id)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Delete password from keychain
            try await securityService.deletePassword(
                service: "\(serviceName).\(id)",
                account: id
            )
            
            // Post notification
            notificationCenter.post(
                name: .credentialsDeleted,
                object: self,
                userInfo: ["repository": id]
            )
            
            logger.info("Successfully deleted credentials", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to delete credentials: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
    
    func list() async throws -> [(repositoryId: String, credentials: RepositoryCredentials)] {
        logger.info("Listing credentials", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Retrieve all passwords from keychain
            let passwords = try await securityService.retrieveAllPasswords(service: serviceName)
            
            // Create credentials for each password
            var credentials: [(String, RepositoryCredentials)] = []
            for (service, password) in passwords {
                let id = service.replacingOccurrences(of: "\(serviceName).", with: "")
                let repositoryCredentials = RepositoryCredentials(password: password)
                credentials.append((id, repositoryCredentials))
            }
            
            logger.info("Successfully listed credentials", privacy: .public, file: #file, function: #function, line: #line)
            return credentials
        } catch {
            logger.error("Failed to list credentials: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
}

/// App-specific implementation of KeychainCredentialsManager
final class AppKeychainCredentialsManager {
    private let manager: KeychainCredentialsManager
    
    init(serviceName: String = "dev.mpy.rBUM.repository") {
        self.manager = KeychainCredentialsManager(serviceName: serviceName)
    }
}

extension AppKeychainCredentialsManager: KeychainCredentialsManagerProtocol {
    func store(_ credentials: RepositoryCredentials, forRepositoryId id: String) async throws {
        try await manager.store(credentials, forRepositoryId: id)
    }
    
    func retrieve(forId id: String) async throws -> RepositoryCredentials {
        try await manager.retrieve(forId: id)
    }
    
    func delete(forId id: String) async throws {
        try await manager.delete(forId: id)
    }
    
    func list() async throws -> [(repositoryId: String, credentials: RepositoryCredentials)] {
        try await manager.list()
    }
}
