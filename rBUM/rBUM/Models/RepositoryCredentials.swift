//
//  RepositoryCredentials.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Represents the credentials for a Restic repository
public struct RepositoryCredentials: Codable, Equatable {
    /// Repository password used for encryption
    public let password: String
    
    /// Path to the repository
    public let repositoryPath: String
    
    public init(repositoryPath: String, password: String) {
        self.repositoryPath = repositoryPath
        self.password = password
    }
}
