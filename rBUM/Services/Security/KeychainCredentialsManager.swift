//
//  KeychainCredentialsManager.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Core
import Foundation

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
    private let keychainService: Core.KeychainServiceProtocol
    private let dateProvider: DateProviderProtocol
    private let notificationCenter: NotificationCenter
    private let serviceName: String
    private let accessGroup = "dev.mpy.rBUM.keychain"
    
    init(
        logger: LoggerProtocol = OSLogger(category: "security"),
        keychainService: Core.KeychainServiceProtocol = {
            let logger = OSLogger(category: "security")
            // Step 1: Create temporary security service with mock XPC
            let tempSecurityService = Core.SecurityService(
                logger: logger,
                xpcService: MockResticXPCService()
            )
            
            // Step 2: Create real XPC service using temporary security service
            let xpcService = Core.ResticXPCService(
                logger: logger,
                securityService: tempSecurityService
            )
            
            // Step 3: Create final security service with real XPC service
            let securityService = Core.SecurityService(
                logger: logger,
                xpcService: xpcService as! Core.ResticXPCServiceProtocol
            )
            
            // Step 4: Create keychain service with security service
            let keychainService = Core.KeychainService(
                logger: logger,
                securityService: securityService
            )
            return keychainService as! Core.KeychainServiceProtocol
        }(),
        dateProvider: DateProviderProtocol = DateProvider(),
        notificationCenter: NotificationCenter = .default,
        serviceName: String = "dev.mpy.rBUM.repository"
    ) {
        self.logger = logger
        self.keychainService = keychainService
        self.dateProvider = dateProvider
        self.notificationCenter = notificationCenter
        self.serviceName = serviceName
        
        logger.debug("Initialized KeychainCredentialsManager", file: #file, function: #function, line: #line)
        
        // Configure keychain sharing
        do {
            try keychainService.configureXPCSharing(accessGroup: accessGroup)
        } catch {
            logger.error("Failed to configure keychain sharing: \(error.localizedDescription)", file: #file, function: #function, line: #line)
        }
    }
    
    func store(_ credentials: RepositoryCredentials, forRepositoryId id: String) async throws {
        logger.debug("Storing credentials for repository: \(id)", file: #file, function: #function, line: #line)
        
        do {
            let data = try JSONEncoder().encode(credentials)
            try keychainService.save(data, for: "\(serviceName).\(id)", accessGroup: accessGroup)
            
            notificationCenter.post(
                name: .init("dev.mpy.rBUM.credentialsStored"),
                object: self,
                userInfo: ["repositoryId": id]
            )
            
            logger.debug("Successfully stored credentials", file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to store credentials: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw CredentialsError.storeFailed(error.localizedDescription)
        }
    }
    
    func retrieve(forId id: String) async throws -> RepositoryCredentials {
        logger.debug("Retrieving credentials for repository: \(id)", file: #file, function: #function, line: #line)
        
        do {
            guard let data = try keychainService.retrieve(for: "\(serviceName).\(id)", accessGroup: accessGroup) else {
                throw CredentialsError.retrievalFailed("No credentials found")
            }
            return try JSONDecoder().decode(RepositoryCredentials.self, from: data)
        } catch {
            logger.error("Failed to retrieve credentials: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw CredentialsError.retrievalFailed(error.localizedDescription)
        }
    }
    
    func delete(forId id: String) async throws {
        logger.debug("Deleting credentials for repository: \(id)", file: #file, function: #function, line: #line)
        
        do {
            try keychainService.delete(for: "\(serviceName).\(id)", accessGroup: accessGroup)
            
            notificationCenter.post(
                name: .init("dev.mpy.rBUM.credentialsDeleted"),
                object: self,
                userInfo: ["repositoryId": id]
            )
            
            logger.debug("Successfully deleted credentials", file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to delete credentials: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw CredentialsError.deletionFailed(error.localizedDescription)
        }
    }
    
    func list() async throws -> [(repositoryId: String, credentials: RepositoryCredentials)] {
        logger.debug("Listing all credentials", file: #file, function: #function, line: #line)
        
        // Since KeychainServiceProtocol doesn't have a list method,
        // we'll need to implement our own using the available methods
        do {
            var results: [(String, RepositoryCredentials)] = []
            
            // Try to retrieve credentials for known repositories
            // This is a temporary solution until we implement proper listing
            if let repositories = try? await listRepositories() {
                for repository in repositories {
                    let repositoryId = repository.id.uuidString
                    if let credentials = try? await retrieve(forId: repositoryId) {
                        results.append((repositoryId, credentials))
                    }
                }
            }
            
            logger.debug("Successfully listed \(results.count) credentials", file: #file, function: #function, line: #line)
            return results
        } catch {
            logger.error("Failed to list credentials: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw CredentialsError.listingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    private func listRepositories() async throws -> [Repository] {
        // This should be injected or accessed through a repository service
        // For now, return an empty array
        return []
    }
}

// MARK: - Credentials Error Types
enum CredentialsError: LocalizedError {
    case storeFailed(String)
    case retrievalFailed(String)
    case deletionFailed(String)
    case listingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .storeFailed(let reason):
            return "Failed to store credentials: \(reason)"
        case .retrievalFailed(let reason):
            return "Failed to retrieve credentials: \(reason)"
        case .deletionFailed(let reason):
            return "Failed to delete credentials: \(reason)"
        case .listingFailed(let reason):
            return "Failed to list credentials: \(reason)"
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
