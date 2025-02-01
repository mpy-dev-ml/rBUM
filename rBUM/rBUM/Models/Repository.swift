//
//  Repository.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation

/// Represents a Restic backup repository
public struct Repository: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String        // Repository display name
    public let path: String          // Local path to repository
    public let createdAt: Date    // Creation timestamp
    
    public init(id: String = UUID().uuidString,
                name: String,
                path: String,
                createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.createdAt = createdAt
    }
    
    // MARK: - Security-Scoped Resource Handling
    
    public func startAccessing() -> Bool {
        guard let url = URL(string: path) else { return false }
        return url.startAccessingSecurityScopedResource()
    }
    
    public func stopAccessing() {
        guard let url = URL(string: path) else { return }
        url.stopAccessingSecurityScopedResource()
    }
}

// MARK: - Repository Errors

public enum RepositoryError: LocalizedError, Equatable {
    // Creation errors
    case invalidPath(String)
    case pathAlreadyExists
    case creationFailed(String)
    case importFailed(String)
    case repositoryAlreadyExists
    case invalidRepository
    
    // Storage errors
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case encodingFailed
    case decodingFailed
    case fileOperationFailed(String)
    
    // Authentication errors
    case invalidPassword
    case resticError(String)
    
    public var errorDescription: String? {
        switch self {
        // Creation errors
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
            
        // Storage errors
        case .bookmarkCreationFailed:
            return "Failed to create security-scoped bookmark"
        case .bookmarkResolutionFailed:
            return "Failed to resolve security-scoped bookmark"
        case .encodingFailed:
            return "Failed to encode repository data"
        case .decodingFailed:
            return "Failed to decode repository data"
        case .fileOperationFailed(let message):
            return "File operation failed: \(message)"
            
        // Authentication errors
        case .invalidPassword:
            return "Invalid repository password"
        case .resticError(let message):
            return "Restic error: \(message)"
        }
    }
}
