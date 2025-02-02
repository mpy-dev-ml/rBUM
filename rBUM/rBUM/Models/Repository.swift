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
    public let path: String        // Local path to repository
    public let createdAt: Date     // Creation timestamp
    public var credentials: RepositoryCredentials?  // Optional credentials for operations
    
    public init(id: String = UUID().uuidString,
                name: String,
                path: String,
                createdAt: Date = Date(),
                credentials: RepositoryCredentials? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.createdAt = createdAt
        self.credentials = credentials
    }
    
    // MARK: - Security-Scoped Resource Handling
    
    private var url: URL? {
        URL(string: path)
    }
    
    public func startAccessing() -> Bool {
        guard let url = self.url else {
            return false
        }
        let hasAccess = url.startAccessingSecurityScopedResource()
        if !hasAccess {
            Logging.logger(for: .repository).error(
                "Failed to access security-scoped resource for repository: \(id, privacy: .public)"
            )
        }
        return hasAccess
    }
    
    public func stopAccessing() {
        guard let url = self.url else { return }
        url.stopAccessingSecurityScopedResource()
    }
    
    /// Safely access a security-scoped resource and perform an operation
    /// - Parameter operation: The operation to perform while the resource is accessible
    /// - Returns: The result of the operation
    /// - Throws: Any error that occurs during the operation
    public func withSecureAccess<T>(_ operation: () throws -> T) throws -> T {
        guard let url = self.url else {
            throw RepositoryError.invalidPath("Invalid URL: \(path)")
        }
        
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        guard hasAccess else {
            throw RepositoryError.accessDenied
        }
        
        return try operation()
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
    case credentialsNotFound
    case accessDenied
    
    // Storage errors
    case storageError(String)
    case retrievalError(String)
    case deletionError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPath(let reason):
            return "Invalid repository path: \(reason)"
        case .pathAlreadyExists:
            return "A repository already exists at this path"
        case .creationFailed(let reason):
            return "Failed to create repository: \(reason)"
        case .importFailed(let reason):
            return "Failed to import repository: \(reason)"
        case .repositoryAlreadyExists:
            return "A repository with this name already exists"
        case .invalidRepository:
            return "Invalid repository format"
        case .credentialsNotFound:
            return "Repository credentials not found"
        case .accessDenied:
            return "Access to the repository was denied"
        case .storageError(let reason):
            return "Failed to store repository: \(reason)"
        case .retrievalError(let reason):
            return "Failed to retrieve repository: \(reason)"
        case .deletionError(let reason):
            return "Failed to delete repository: \(reason)"
        }
    }
}
