//
//  RepositoryCreationService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Errors that can occur during repository creation
enum RepositoryCreationError: LocalizedError, Equatable {
    case invalidPath(String)
    case pathAlreadyExists
    case creationFailed(String)
    case importFailed(String)
    case repositoryAlreadyExists
    case invalidRepository
    
    var errorDescription: String? {
        switch self {
        case .invalidPath(let reason):
            return "Invalid repository path: \(reason)"
        case .pathAlreadyExists:
            return "A file or directory already exists at this path"
        case .creationFailed(let reason):
            return "Failed to create repository: \(reason)"
        case .importFailed(let reason):
            return "Failed to import repository: \(reason)"
        case .repositoryAlreadyExists:
            return "A repository already exists at this location"
        case .invalidRepository:
            return "The specified path is not a valid Restic repository"
        }
    }
    
    static func == (lhs: RepositoryCreationError, rhs: RepositoryCreationError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidPath(let l), .invalidPath(let r)):
            return l == r
        case (.pathAlreadyExists, .pathAlreadyExists):
            return true
        case (.creationFailed(let l), .creationFailed(let r)):
            return l == r
        case (.importFailed(let l), .importFailed(let r)):
            return l == r
        case (.repositoryAlreadyExists, .repositoryAlreadyExists):
            return true
        case (.invalidRepository, .invalidRepository):
            return true
        default:
            return false
        }
    }
}

/// Protocol for creating and importing repositories
protocol RepositoryCreationServiceProtocol {
    /// Create a new repository at the specified path
    /// - Parameters:
    ///   - name: Name of the repository
    ///   - path: Path where the repository should be created
    ///   - password: Password to encrypt the repository
    /// - Returns: The created repository
    func createRepository(name: String, path: URL, password: String) async throws -> Repository
    
    /// Import an existing repository from the specified path
    /// - Parameters:
    ///   - name: Name for the repository
    ///   - path: Path to the existing repository
    ///   - password: Password to access the repository
    /// - Returns: The imported repository
    func importRepository(name: String, path: URL, password: String) async throws -> Repository
}

/// Service for creating and importing repositories
final class RepositoryCreationService: RepositoryCreationServiceProtocol {
    private let resticService: ResticCommandServiceProtocol
    private let repositoryStorage: RepositoryStorageProtocol
    private let fileManager: FileManager
    private let logger = Logging.logger(for: .repository)
    
    init(
        resticService: ResticCommandServiceProtocol,
        repositoryStorage: RepositoryStorageProtocol,
        fileManager: FileManager = .default
    ) {
        self.resticService = resticService
        self.repositoryStorage = repositoryStorage
        self.fileManager = fileManager
    }
    
    func createRepository(name: String, path: URL, password: String) async throws -> Repository {
        // Validate path
        guard path.isFileURL else {
            throw RepositoryCreationError.invalidPath("Must be a file URL")
        }
        
        // Check if path exists
        if fileManager.fileExists(atPath: path.path) {
            // Check if repository already exists
            if try repositoryStorage.exists(atPath: path, excludingId: nil) {
                throw RepositoryCreationError.repositoryAlreadyExists
            } else {
                throw RepositoryCreationError.pathAlreadyExists
            }
        } else {
            // Create directory
            do {
                try fileManager.createDirectory(
                    at: path,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw RepositoryCreationError.creationFailed("Failed to create directory: \(error.localizedDescription)")
            }
        }
        
        // Create repository
        let repository = Repository(
            name: name,
            path: path
        )
        
        do {
            // Initialize repository with restic
            try await resticService.initializeRepository(at: path, password: password)
            
            // Store repository metadata
            try repositoryStorage.store(repository)
            
            logger.infoMessage("Created repository: \(repository.id) at \(path.path)")
            return repository
        } catch ResticError.commandFailed(let error) {
            // Clean up failed repository
            try? fileManager.removeItem(at: path)
            throw RepositoryCreationError.creationFailed(error)
        } catch {
            // Clean up failed repository
            try? fileManager.removeItem(at: path)
            throw RepositoryCreationError.creationFailed(error.localizedDescription)
        }
    }
    
    func importRepository(name: String, path: URL, password: String) async throws -> Repository {
        // Validate path
        guard path.isFileURL else {
            throw RepositoryCreationError.invalidPath("Must be a file URL")
        }
        
        // Check if path exists
        guard fileManager.fileExists(atPath: path.path) else {
            throw RepositoryCreationError.invalidPath("Repository not found at path")
        }
        
        // Check if repository already imported
        if try repositoryStorage.exists(atPath: path, excludingId: nil) {
            throw RepositoryCreationError.repositoryAlreadyExists
        }
        
        // Create repository
        let repository = Repository(
            name: name,
            path: path
        )
        
        do {
            // Verify repository with restic
            try await resticService.checkRepository(path, withPassword: password)
            
            // Store repository metadata
            try repositoryStorage.store(repository)
            
            logger.infoMessage("Imported repository: \(repository.id) from \(path.path)")
            return repository
        } catch ResticError.invalidRepository {
            throw RepositoryCreationError.invalidRepository
        } catch ResticError.commandFailed(let error) {
            throw RepositoryCreationError.importFailed(error)
        } catch {
            throw RepositoryCreationError.importFailed(error.localizedDescription)
        }
    }
}
