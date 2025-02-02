//
//  RepositoryCreationService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import os

/// Protocol for creating and importing repositories
protocol RepositoryCreationServiceProtocol {
    /// Create a new repository at the specified path
    /// - Parameters:
    ///   - name: Name of the repository
    ///   - path: Path where the repository should be created
    ///   - password: Password to encrypt the repository
    /// - Returns: The created repository
    func createRepository(name: String, path: String, password: String) async throws -> Repository
    
    /// Import an existing repository from the specified path
    /// - Parameters:
    ///   - name: Name for the repository
    ///   - path: Path to the existing repository
    ///   - password: Password to access the repository
    /// - Returns: The imported repository
    func importRepository(name: String, path: String, password: String) async throws -> Repository
}

/// Service for creating and importing repositories
final class RepositoryCreationService: RepositoryCreationServiceProtocol {
    private let resticService: ResticCommandServiceProtocol
    private let repositoryStorage: RepositoryStorageProtocol
    private let logger: Logger
    
    init(resticService: ResticCommandServiceProtocol, repositoryStorage: RepositoryStorageProtocol) {
        self.resticService = resticService
        self.repositoryStorage = repositoryStorage
        self.logger = Logging.logger(for: .creation)
    }
    
    func createRepository(name: String, path: String, password: String) async throws -> Repository {
        logger.info("\(name, privacy: .private) at \(path, privacy: .private)")
        
        // Create repository using restic
        let credentials = RepositoryCredentials(repositoryPath: path, password: password)
        try await resticService.initRepository(credentials: credentials)
        
        // Create and save repository
        let repository = Repository(name: name, path: path)
        try await repositoryStorage.save(repository)
        
        logger.info("\(repository.id, privacy: .public)")
        return repository
    }
    
    func importRepository(name: String, path: String, password: String) async throws -> Repository {
        logger.info("\(name, privacy: .private) from \(path, privacy: .private)")
        
        // Verify repository using restic
        let credentials = RepositoryCredentials(repositoryPath: path, password: password)
        try await resticService.checkRepository(credentials: credentials)
        
        // Create and save repository
        let repository = Repository(name: name, path: path)
        try await repositoryStorage.save(repository)
        
        logger.info("\(repository.id, privacy: .public)")
        return repository
    }
}
