//
//  CredentialsStorage.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Protocol for storing repository credentials metadata
protocol CredentialsStorageProtocol {
    /// Store credentials metadata
    /// - Parameter credentials: The credentials to store
    func store(_ credentials: RepositoryCredentials) throws
    
    /// Retrieve credentials metadata for a repository
    /// - Parameter repositoryId: The repository ID
    /// - Returns: The stored credentials metadata
    func retrieve(forRepositoryId repositoryId: UUID) throws -> RepositoryCredentials?
    
    /// List all stored credentials metadata
    /// - Returns: Array of stored credentials metadata
    func list() throws -> [RepositoryCredentials]
    
    /// Delete credentials metadata
    /// - Parameter repositoryId: The repository ID
    func delete(forRepositoryId repositoryId: UUID) throws
}

/// Error types for credentials storage operations
enum CredentialsStorageError: LocalizedError {
    case fileOperationFailed(String)
    case invalidData
    case credentialsNotFound
    
    var errorDescription: String? {
        switch self {
        case .fileOperationFailed(let operation):
            return "Failed to \(operation) credentials file"
        case .invalidData:
            return "Invalid credentials data format"
        case .credentialsNotFound:
            return "Credentials not found"
        }
    }
}

/// Manages the storage of repository credentials metadata using FileManager
final class CredentialsStorage: CredentialsStorageProtocol {
    private let fileManager: FileManager
    private let logger = Logging.logger(for: .keychain)
    private let customStorageURL: URL?
    
    /// URL where credentials metadata is stored
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
            .appendingPathComponent("credentials.json")
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
    
    func store(_ credentials: RepositoryCredentials) throws {
        var existingCredentials = try list()
        
        // Update or append
        if let index = existingCredentials.firstIndex(where: { $0.repositoryId == credentials.repositoryId }) {
            existingCredentials[index] = credentials
        } else {
            existingCredentials.append(credentials)
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(existingCredentials)
            try data.write(to: storageURL, options: .atomic)
            logger.infoMessage("Stored credentials for repository: \(credentials.repositoryId)")
        } catch {
            logger.errorMessage("Failed to store credentials: \(error.localizedDescription)")
            throw CredentialsStorageError.fileOperationFailed("write")
        }
    }
    
    func retrieve(forRepositoryId repositoryId: UUID) throws -> RepositoryCredentials? {
        let credentials = try list()
        return credentials.first { $0.repositoryId == repositoryId }
    }
    
    func list() throws -> [RepositoryCredentials] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([RepositoryCredentials].self, from: data)
        } catch {
            logger.errorMessage("Failed to read credentials: \(error.localizedDescription)")
            throw CredentialsStorageError.fileOperationFailed("read")
        }
    }
    
    func delete(forRepositoryId repositoryId: UUID) throws {
        var credentials = try list()
        credentials.removeAll { $0.repositoryId == repositoryId }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(credentials)
            try data.write(to: storageURL, options: .atomic)
            logger.infoMessage("Deleted credentials for repository: \(repositoryId)")
        } catch {
            logger.errorMessage("Failed to delete credentials: \(error.localizedDescription)")
            throw CredentialsStorageError.fileOperationFailed("delete")
        }
    }
}
