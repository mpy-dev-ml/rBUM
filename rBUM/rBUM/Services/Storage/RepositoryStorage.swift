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
    func store(_ repository: Repository) throws
    
    /// Retrieve repository metadata by ID
    func retrieve(forId id: UUID) throws -> Repository?
    
    /// List all stored repositories
    func list() throws -> [Repository]
    
    /// Delete repository metadata
    func delete(forId id: UUID) throws
    
    /// Check if repository exists at path
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool
}

/// Errors that can occur during repository storage operations
enum RepositoryStorageError: LocalizedError, Equatable {
    case fileOperationFailed(String)
    case invalidData(String)
    case repositoryNotFound(UUID)
    case repositoryAlreadyExists
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileOperationFailed(let message):
            return "File operation failed: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .repositoryNotFound(let id):
            return "Repository not found with ID: \(id)"
        case .repositoryAlreadyExists:
            return "Repository already exists at this location"
        case .saveFailed(let error):
            return "Failed to save repository: \(error.localizedDescription)"
        }
    }
    
    static func == (lhs: RepositoryStorageError, rhs: RepositoryStorageError) -> Bool {
        switch (lhs, rhs) {
        case (.fileOperationFailed(let lhsOp), .fileOperationFailed(let rhsOp)):
            return lhsOp == rhsOp
        case (.invalidData(let lhsOp), .invalidData(let rhsOp)):
            return lhsOp == rhsOp
        case (.repositoryNotFound(let lhsId), .repositoryNotFound(let rhsId)):
            return lhsId == rhsId
        case (.repositoryAlreadyExists, .repositoryAlreadyExists):
            return true
        case (.saveFailed(let lhsError), .saveFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Manages repository metadata persistence
final class RepositoryStorage: RepositoryStorageProtocol {
    func store(_ repository: Repository) throws {
        try save(repository)
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
        guard repositories.contains(where: { $0.id == id }) else {
            throw RepositoryStorageError.repositoryNotFound(id)
        }
        
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
    
    private let fileManager: FileManager
    private let logger = Logging.logger(for: .repository)
    private let customStorageURL: URL?  // Optional custom storage location
    
    /// Get the storage URL for repositories
    private var storageURL: URL {
        if let customURL = customStorageURL {
            return customURL
        }
        
        do {
            let appDirectory = try getApplicationSupportDirectory()
            return appDirectory.appendingPathComponent("Repositories", isDirectory: true)
        } catch {
            // Fallback to temporary directory if we can't access application support
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("dev.mpy.rBUM")
                .appendingPathComponent("Repositories", isDirectory: true)
        }
    }
    
    init(fileManager: FileManager = .default, storageURL: URL? = nil) {
        self.fileManager = fileManager
        self.customStorageURL = storageURL
        try? createStorageDirectoryIfNeeded()
    }
    
    private func getApplicationSupportDirectory() throws -> URL {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw RepositoryStorageError.fileOperationFailed("directory not found")
        }
        
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.mpy.rBUM"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID)
        
        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        
        return appDirectory
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
    
    public func save(_ repository: Repository) throws {
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
        } catch {
            throw RepositoryStorageError.saveFailed(error)
        }
    }
    
    public func retrieve(forId id: UUID) throws -> Repository? {
        let repositories = try list()
        return repositories.first { $0.id == id }
    }
    
    public func loadAll() throws -> [Repository] {
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
    
    public func delete(_ repository: Repository) throws {
        var repositories = try list()
        repositories.removeAll { $0.id == repository.id }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(repositories)
            try data.write(to: storageURL, options: .atomic)
            logger.infoMessage("Deleted repository: \(repository.id)")
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
