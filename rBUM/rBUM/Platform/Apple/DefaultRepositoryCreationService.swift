//
//  DefaultRepositoryCreationService.swift
//  rBUM
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation
import Logging
import Core

/// Default repository creation service implementation for macOS
final class DefaultRepositoryCreationService: RepositoryCreationServiceProtocol {
    // MARK: - Properties
    
    private let repositoryService: RepositoryServiceProtocol
    private let logger: Logger
    
    // MARK: - Initialization
    
    init(
        repositoryService: RepositoryServiceProtocol = DefaultRepositoryService(),
        logger: Logger = Logger(label: "dev.mpy.rbum.repository.creation")
    ) {
        self.repositoryService = repositoryService
        self.logger = logger
        
        logger.debug("Service initialised")
    }
    
    // MARK: - Repository Operations
    
    func createRepository(name: String, at url: URL, password: String) async throws -> Repository {
        logger.debug("Creating repository", metadata: [
            "name": .string(name),
            "path": .string(url.path)
        ])
        
        do {
            // Create repository using Core service
            let repository = try await repositoryService.initializeRepository(at: url, password: password)
            
            logger.info("Repository created successfully", metadata: [
                "id": .string(repository.id),
                "name": .string(repository.name),
                "path": .string(repository.path)
            ])
            
            return repository
            
        } catch {
            logger.error("Failed to create repository", metadata: [
                "name": .string(name),
                "path": .string(url.path),
                "error": .string(error.localizedDescription)
            ])
            throw error
        }
    }
    
    func importRepository(name: String, at url: URL, password: String) async throws -> Repository {
        logger.debug("Importing repository", metadata: [
            "name": .string(name),
            "path": .string(url.path)
        ])
        
        do {
            // Create credentials and repository
            let credentials = RepositoryCredentials(path: url.path, password: password)
            let repository = Repository(url: url, credentials: credentials, logger: logger)
            
            // Verify repository using Core service
            let status = try await repositoryService.checkRepository(repository, credentials: credentials)
            
            if status != .ready {
                logger.error("Repository check failed", metadata: [
                    "name": .string(name),
                    "path": .string(url.path),
                    "status": .string("\(status)")
                ])
                throw RepositoryError.invalidRepository
            }
            
            logger.info("Repository imported successfully", metadata: [
                "id": .string(repository.id),
                "name": .string(repository.name),
                "path": .string(repository.path),
                "status": .string("\(status)")
            ])
            
            return repository
            
        } catch {
            logger.error("Failed to import repository", metadata: [
                "name": .string(name),
                "path": .string(url.path),
                "error": .string(error.localizedDescription)
            ])
            throw error
        }
    }
}
