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
    /// - Parameter repositoryId: The ID of the repository these credentials belong to
    /// - Throws: Error if storage fails
    func store(_ credentials: RepositoryCredentials, forRepositoryId repositoryId: String) throws
    
    /// Update existing credentials metadata
    /// - Parameter credentials: The updated credentials
    /// - Parameter repositoryId: The ID of the repository these credentials belong to
    /// - Throws: Error if update fails
    func update(_ credentials: RepositoryCredentials, forRepositoryId repositoryId: String) throws
    
    /// Retrieve credentials metadata for a repository
    /// - Parameter id: The repository ID
    /// - Returns: The credentials metadata if found
    /// - Throws: Error if retrieval fails
    func retrieve(forRepositoryId id: String) throws -> RepositoryCredentials?
    
    /// Delete credentials metadata for a repository
    /// - Parameter id: The repository ID
    /// - Throws: Error if deletion fails
    func delete(forRepositoryId id: String) throws
    
    /// List all stored credentials
    /// - Returns: Array of all stored credentials
    /// - Throws: Error if listing fails
    func list() throws -> [(repositoryId: String, credentials: RepositoryCredentials)]
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

/// Service for storing repository credentials metadata
final class CredentialsStorage: CredentialsStorageProtocol {
    private let fileManager: FileManager
    private let logger: Logger
    private let credentialsDirectory: URL
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.mpy.rBUM", 
                           category: "Credentials")
        
        // Set up credentials directory in Application Support
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.credentialsDirectory = appSupport.appendingPathComponent("Credentials", isDirectory: true)
        
        // Create directory if needed
        try? createCredentialsDirectoryIfNeeded()
    }
    
    func store(_ credentials: RepositoryCredentials, forRepositoryId repositoryId: String) throws {
        logger.info("Storing credentials for repository: \(repositoryId, privacy: .private)")
        
        let fileURL = credentialsDirectory.appendingPathComponent("\(repositoryId).json")
        let data = try JSONEncoder().encode(credentials)
        try data.write(to: fileURL)
    }
    
    func update(_ credentials: RepositoryCredentials, forRepositoryId repositoryId: String) throws {
        logger.info("Updating credentials for repository: \(repositoryId, privacy: .private)")
        
        let fileURL = credentialsDirectory.appendingPathComponent("\(repositoryId).json")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw CredentialsStorageError.credentialsNotFound
        }
        
        let data = try JSONEncoder().encode(credentials)
        try data.write(to: fileURL)
    }
    
    func retrieve(forRepositoryId id: String) throws -> RepositoryCredentials? {
        logger.info("Retrieving credentials for repository: \(id, privacy: .private)")
        
        let fileURL = credentialsDirectory.appendingPathComponent("\(id).json")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(RepositoryCredentials.self, from: data)
    }
    
    func delete(forRepositoryId id: String) throws {
        logger.info("Deleting credentials for repository: \(id, privacy: .private)")
        
        let fileURL = credentialsDirectory.appendingPathComponent("\(id).json")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        
        try fileManager.removeItem(at: fileURL)
    }
    
    func list() throws -> [(repositoryId: String, credentials: RepositoryCredentials)] {
        logger.info("Listing all credentials")
        
        let files = try fileManager.contentsOfDirectory(
            at: credentialsDirectory,
            includingPropertiesForKeys: nil
        )
        
        return try files.compactMap { fileURL in
            guard fileURL.pathExtension == "json" else { return nil }
            let repositoryId = fileURL.deletingPathExtension().lastPathComponent
            let data = try Data(contentsOf: fileURL)
            let credentials = try JSONDecoder().decode(RepositoryCredentials.self, from: data)
            return (repositoryId: repositoryId, credentials: credentials)
        }
    }
    
    // MARK: - Private Methods
    
    private func createCredentialsDirectoryIfNeeded() throws {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: credentialsDirectory.path, isDirectory: &isDirectory) {
            try fileManager.createDirectory(
                at: credentialsDirectory,
                withIntermediateDirectories: true
            )
        }
    }
}

/// Mock implementation of CredentialsStorage for previews and testing
final class MockCredentialsStorage: CredentialsStorageProtocol {
    private var credentials: [String: RepositoryCredentials] = [:]
    
    func store(_ credentials: RepositoryCredentials, forRepositoryId repositoryId: String) throws {
        self.credentials[repositoryId] = credentials
    }
    
    func update(_ credentials: RepositoryCredentials, forRepositoryId repositoryId: String) throws {
        guard self.credentials[repositoryId] != nil else {
            throw CredentialsStorageError.credentialsNotFound
        }
        self.credentials[repositoryId] = credentials
    }
    
    func retrieve(forRepositoryId id: String) throws -> RepositoryCredentials? {
        credentials[id]
    }
    
    func delete(forRepositoryId id: String) throws {
        credentials.removeValue(forKey: id)
    }
    
    func list() throws -> [(repositoryId: String, credentials: RepositoryCredentials)] {
        credentials.map { (repositoryId: $0.key, credentials: $0.value) }
    }
}
