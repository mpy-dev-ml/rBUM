//
//  CredentialsStorage.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import os

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
    private let logger: Logger
    private let credentialsDirectory: URL
    
    init(fileManager: FileManager = .default, logger: Logger = Logger(subsystem: "dev.mpy.rBUM", category: "Storage")) {
        self.fileManager = fileManager
        self.logger = logger
        
        // Get the application support directory
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not access Application Support directory")
        }
        
        // Create the credentials directory path
        self.credentialsDirectory = appSupportDir.appendingPathComponent("rBUM/Credentials", isDirectory: true)
        
        // Ensure the directory exists
        try? self.createCredentialsDirectoryIfNeeded()
    }
    
    func store(_ credentials: RepositoryCredentials) throws {
        try createCredentialsDirectoryIfNeeded()
        let url = credentialsDirectory.appendingPathComponent("\(credentials.repositoryId.uuidString).json")
        let data = try JSONEncoder().encode(credentials)
        try data.write(to: url)
        self.logger.log("Saved credentials for repository: \(credentials.repositoryId)")
    }
    
    func update(_ credentials: RepositoryCredentials) throws {
        try createCredentialsDirectoryIfNeeded()
        let url = credentialsDirectory.appendingPathComponent("\(credentials.repositoryId.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else {
            throw CredentialsStorageError.credentialsNotFound
        }
        let data = try JSONEncoder().encode(credentials)
        try data.write(to: url)
        self.logger.log("Updated credentials for repository: \(credentials.repositoryId)")
    }
    
    func retrieve(forRepositoryId id: UUID) throws -> RepositoryCredentials? {
        try createCredentialsDirectoryIfNeeded()
        let url = credentialsDirectory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        let credentials = try JSONDecoder().decode(RepositoryCredentials.self, from: data)
        self.logger.log("Loaded credentials for repository: \(id)")
        return credentials
    }
    
    func delete(forRepositoryId id: UUID) throws {
        try createCredentialsDirectoryIfNeeded()
        let url = credentialsDirectory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else {
            throw CredentialsStorageError.credentialsNotFound
        }
        do {
            try fileManager.removeItem(at: url)
            self.logger.log("Deleted credentials for repository: \(id)")
        } catch {
            self.logger.log("Failed to delete credentials: \(error.localizedDescription)")
            throw error
        }
    }
    
    func list() throws -> [RepositoryCredentials] {
        // Create directory if it doesn't exist
        try createCredentialsDirectoryIfNeeded()
        
        // Get directory contents
        let contents = try fileManager.contentsOfDirectory(
            at: credentialsDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        // Load and decode each credential file
        var credentials: [RepositoryCredentials] = []
        for url in contents where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                if let credential = try? JSONDecoder().decode(RepositoryCredentials.self, from: data) {
                    credentials.append(credential)
                }
            } catch {
                self.logger.log("Failed to load credentials from \(url.lastPathComponent): \(error.localizedDescription)")
                continue
            }
        }
        self.logger.log("Loaded all credentials")
        return credentials
    }
    
    // MARK: - Private Methods
    
    private func createCredentialsDirectoryIfNeeded() throws {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: credentialsDirectory.path, isDirectory: &isDirectory) {
            try fileManager.createDirectory(
                at: credentialsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            self.logger.log("Created credentials directory at: \(self.credentialsDirectory.path)")
        } else if !isDirectory.boolValue {
            // If path exists but is not a directory, remove it and create directory
            try fileManager.removeItem(at: credentialsDirectory)
            try fileManager.createDirectory(
                at: credentialsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            self.logger.log("Replaced file with directory at: \(self.credentialsDirectory.path)")
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
