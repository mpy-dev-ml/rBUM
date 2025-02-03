//
//  Repository.swift
//  Core
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation

/// Represents a Restic backup repository
public struct Repository: Codable, Identifiable, Equatable {
    /// Unique identifier for the repository
    public let id: UUID
    
    /// Path to the repository
    public let path: String
    
    /// Name of the repository
    public let name: String
    
    /// Optional description of the repository
    public let description: String?
    
    /// Credentials for accessing the repository
    public let credentials: RepositoryCredentials
    
    /// Creates a new repository
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - path: Path to the repository
    ///   - name: Name of the repository
    ///   - description: Optional description
    ///   - credentials: Credentials for accessing the repository
    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        description: String? = nil,
        credentials: RepositoryCredentials
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.description = description
        self.credentials = credentials
    }
}
