//
//  CredentialsStorage.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Protocol defining the interface for storing repository credentials metadata
protocol CredentialsStorageProtocol {
    /// Store new credentials metadata
    /// - Parameter credentials: The credentials to store
    /// - Throws: Error if storage fails
    func store(_ credentials: RepositoryCredentials) throws
    
    /// Update existing credentials metadata
    /// - Parameter credentials: The updated credentials
    /// - Throws: Error if update fails
    func update(_ credentials: RepositoryCredentials) throws
    
    /// Retrieve credentials metadata for a repository
    /// - Parameter id: The repository ID
    /// - Returns: The credentials metadata if found
    /// - Throws: Error if retrieval fails
    func retrieve(forRepositoryId id: UUID) throws -> RepositoryCredentials?
    
    /// Delete credentials metadata for a repository
    /// - Parameter id: The repository ID
    /// - Throws: Error if deletion fails
    func delete(forRepositoryId id: UUID) throws
    
    /// List all stored credentials
    /// - Returns: Array of all stored credentials
    /// - Throws: Error if listing fails
    func list() throws -> [RepositoryCredentials]
}

/// Error types for credentials storage operations
enum CredentialsStorageError: LocalizedError {
    case fileOperationFailed(String)
    case credentialsNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .fileOperationFailed(let operation):
            return "Failed to \(operation) credentials"
        case .credentialsNotFound:
            return "Credentials not found"
        case .invalidData:
            return "Invalid credentials data"
        }
    }
}

/// File-based implementation of CredentialsStorageProtocol
final class CredentialsStorage: CredentialsStorageProtocol {
    private let fileManager: FileManager
    private let logger = Logging.logger(for: .storage)
    
    /// Directory where credentials metadata is stored
    private var credentialsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("dev.mpy.rBUM/credentials", isDirectory: true)
    }
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        try? createCredentialsDirectory()
    }
    
    func store(_ credentials: RepositoryCredentials) throws {
        let url = credentialsDirectory.appendingPathComponent("\(credentials.repositoryId.uuidString).json")
        let data = try JSONEncoder().encode(credentials)
        try data.write(to: url)
        logger.infoMessage("Stored credentials metadata for repository: \(credentials.repositoryId)")
    }
    
    func update(_ credentials: RepositoryCredentials) throws {
        let url = credentialsDirectory.appendingPathComponent("\(credentials.repositoryId.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else {
            throw CredentialsStorageError.credentialsNotFound
        }
        let data = try JSONEncoder().encode(credentials)
        try data.write(to: url)
        logger.infoMessage("Updated credentials metadata for repository: \(credentials.repositoryId)")
    }
    
    func retrieve(forRepositoryId id: UUID) throws -> RepositoryCredentials? {
        let url = credentialsDirectory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RepositoryCredentials.self, from: data)
    }
    
    func delete(forRepositoryId id: UUID) throws {
        let url = credentialsDirectory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else {
            throw CredentialsStorageError.credentialsNotFound
        }
        try fileManager.removeItem(at: url)
        logger.infoMessage("Deleted credentials metadata for repository: \(id)")
    }
    
    func list() throws -> [RepositoryCredentials] {
        let contents = try fileManager.contentsOfDirectory(at: credentialsDirectory, includingPropertiesForKeys: nil)
        var credentials: [RepositoryCredentials] = []
        for url in contents {
            guard url.pathExtension == "json" else { continue }
            let data = try Data(contentsOf: url)
            let credential = try JSONDecoder().decode(RepositoryCredentials.self, from: data)
            credentials.append(credential)
        }
        return credentials
    }
    
    // MARK: - Private Methods
    
    private func createCredentialsDirectory() throws {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: credentialsDirectory.path, isDirectory: &isDirectory) {
            try fileManager.createDirectory(at: credentialsDirectory, withIntermediateDirectories: true)
            logger.infoMessage("Created credentials directory at: \(credentialsDirectory.path)")
        }
    }
}

/// Mock implementation of CredentialsStorage for previews and testing
final class MockCredentialsStorage: CredentialsStorageProtocol {
    private var credentials: [UUID: RepositoryCredentials] = [:]
    
    func store(_ credentials: RepositoryCredentials) throws {
        self.credentials[credentials.repositoryId] = credentials
    }
    
    func update(_ credentials: RepositoryCredentials) throws {
        guard self.credentials[credentials.repositoryId] != nil else {
            throw CredentialsError.notFound
        }
        self.credentials[credentials.repositoryId] = credentials
    }
    
    func retrieve(forRepositoryId id: UUID) throws -> RepositoryCredentials? {
        credentials[id]
    }
    
    func delete(forRepositoryId id: UUID) throws {
        guard credentials[id] != nil else {
            throw CredentialsError.notFound
        }
        credentials.removeValue(forKey: id)
    }
    
    func list() throws -> [RepositoryCredentials] {
        Array(credentials.values)
    }
}
