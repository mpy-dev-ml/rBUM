//
//  RepositoryStorage.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Protocol for managing repository storage
protocol RepositoryStorageProtocol {
    /// Store repository metadata
    /// - Parameter repository: The repository to store
    func store(_ repository: Repository) throws
    
    /// Retrieve repository metadata by ID
    /// - Parameter id: The repository ID
    /// - Returns: The stored repository metadata
    func retrieve(forId id: UUID) throws -> Repository?
    
    /// List all stored repositories
    /// - Returns: Array of stored repositories
    func list() throws -> [Repository]
    
    /// Delete repository metadata
    /// - Parameter id: The repository ID
    func delete(forId id: UUID) throws
    
    /// Check if a repository exists at the given path
    /// - Parameters:
    ///   - path: The path to check
    ///   - excludingId: Optional ID of repository to exclude from check
    /// - Returns: True if a repository exists at the path
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool
}

/// Error types for repository storage operations
enum RepositoryStorageError: LocalizedError, Equatable {
    case fileOperationFailed(String)
    case invalidData
    case repositoryNotFound
    case repositoryAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .fileOperationFailed(let operation):
            return "Failed to \(operation) repository file"
        case .invalidData:
            return "Invalid repository data format"
        case .repositoryNotFound:
            return "Repository not found"
        case .repositoryAlreadyExists:
            return "Repository already exists at this location"
        }
    }
    
    static func == (lhs: RepositoryStorageError, rhs: RepositoryStorageError) -> Bool {
        switch (lhs, rhs) {
        case (.fileOperationFailed(let lhsOp), .fileOperationFailed(let rhsOp)):
            return lhsOp == rhsOp
        case (.invalidData, .invalidData):
            return true
        case (.repositoryNotFound, .repositoryNotFound):
            return true
        case (.repositoryAlreadyExists, .repositoryAlreadyExists):
            return true
        default:
            return false
        }
    }
}

/// Manages the storage of repository metadata using FileManager
final class RepositoryStorage: RepositoryStorageProtocol {
    private let fileManager: FileManager
    private let logger = Logging.logger(for: .repository)
    private let customStorageURL: URL?
    
    /// URL where repository metadata is stored
    private var storageURL: URL {
        if let customURL = customStorageURL {
            return customURL
        }
        
        let appSupport = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent("dev.mpy.rBUM", isDirectory: true)
            .appendingPathComponent("repositories.json")
    }
    
    init(fileManager: FileManager = .default, storageURL: URL? = nil) {
        self.fileManager = fileManager
        self.customStorageURL = storageURL
        try? createStorageDirectoryIfNeeded()
    }
    
    private func createStorageDirectoryIfNeeded() throws {
        let directory = storageURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    func store(_ repository: Repository) throws {
        var existingRepositories = try list()
        
        // Check if a repository already exists at this path (excluding current repository)
        if try exists(atPath: repository.path, excludingId: repository.id) {
            throw RepositoryStorageError.repositoryAlreadyExists
        }
        
        // Update or append
        if let index = existingRepositories.firstIndex(where: { $0.id == repository.id }) {
            existingRepositories[index] = repository
        } else {
            existingRepositories.append(repository)
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(existingRepositories)
            try data.write(to: storageURL, options: .atomic)
            logger.infoMessage("Stored repository: \(repository.id)")
        } catch {
            logger.errorMessage("Failed to store repository: \(error.localizedDescription)")
            throw RepositoryStorageError.fileOperationFailed("write")
        }
    }
    
    func retrieve(forId id: UUID) throws -> Repository? {
        let repositories = try list()
        return repositories.first { $0.id == id }
    }
    
    func list() throws -> [Repository] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Repository].self, from: data)
        } catch {
            logger.errorMessage("Failed to read repositories: \(error.localizedDescription)")
            throw RepositoryStorageError.fileOperationFailed("read")
        }
    }
    
    func delete(forId id: UUID) throws {
        var repositories = try list()
        repositories.removeAll { $0.id == id }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(repositories)
            try data.write(to: storageURL, options: .atomic)
            logger.infoMessage("Deleted repository: \(id)")
        } catch {
            logger.errorMessage("Failed to delete repository: \(error.localizedDescription)")
            throw RepositoryStorageError.fileOperationFailed("delete")
        }
    }
    
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool {
        let repositories = try list()
        return repositories.contains { repository in
            if let excludingId = excludingId, repository.id == excludingId {
                return false
            }
            return repository.path == path
        }
    }
    
    func exists(atPath path: URL) throws -> Bool {
        return try exists(atPath: path, excludingId: nil)
    }
}
