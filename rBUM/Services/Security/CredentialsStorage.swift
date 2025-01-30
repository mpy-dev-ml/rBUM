//
//  CredentialsStorage.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// A thread-safe storage mechanism for repository credentials
final class CredentialsStorage {
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.CredentialsStorage", attributes: .concurrent)
    private let credentialsDirectory: URL
    
    init(testDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        if let testDirectory = testDirectory {
            credentialsDirectory = testDirectory
        } else {
            // Get the application support directory
            let appSupportURLs = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            guard let appSupportURL = appSupportURLs.first else {
                fatalError("Failed to get application support directory")
            }
            
            // Create our app's directory
            let appDirectory = appSupportURL.appendingPathComponent("dev.mpy.rBUM", isDirectory: true)
            
            // Create the credentials directory
            credentialsDirectory = appDirectory.appendingPathComponent("credentials", isDirectory: true)
        }
        
        // Create directories if they don't exist
        do {
            try fileManager.createDirectory(at: credentialsDirectory, withIntermediateDirectories: true)
        } catch {
            // Don't fail init, let the operations handle the errors
            print("Warning: Failed to create credentials directory: \(error)")
        }
    }
    
    /// Store credentials for a repository
    func store(_ credentials: RepositoryCredentials) throws {
        try queue.sync(flags: .barrier) {
            // Ensure directory exists
            try fileManager.createDirectory(at: credentialsDirectory, withIntermediateDirectories: true)
            
            let data = try JSONEncoder().encode(credentials)
            let fileURL = credentialsDirectory.appendingPathComponent("\(credentials.repositoryId).json")
            try data.write(to: fileURL, options: .atomic)
        }
    }
    
    /// Retrieve credentials for a repository
    func retrieve(forRepositoryId id: UUID) throws -> RepositoryCredentials? {
        try queue.sync {
            let fileURL = credentialsDirectory.appendingPathComponent("\(id).json")
            guard let data = try? Data(contentsOf: fileURL) else {
                return nil
            }
            return try JSONDecoder().decode(RepositoryCredentials.self, from: data)
        }
    }
    
    /// Delete credentials for a repository
    func delete(forRepositoryId id: UUID) throws {
        try queue.sync(flags: .barrier) {
            let fileURL = credentialsDirectory.appendingPathComponent("\(id).json")
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    /// List all stored credentials
    func list() throws -> [RepositoryCredentials] {
        try queue.sync {
            // Ensure directory exists
            if !fileManager.fileExists(atPath: credentialsDirectory.path) {
                return []
            }
            
            let fileURLs = try fileManager.contentsOfDirectory(at: credentialsDirectory, includingPropertiesForKeys: nil)
            return try fileURLs.compactMap { fileURL in
                guard let data = try? Data(contentsOf: fileURL) else {
                    return nil
                }
                return try? JSONDecoder().decode(RepositoryCredentials.self, from: data)
            }
        }
    }
}
