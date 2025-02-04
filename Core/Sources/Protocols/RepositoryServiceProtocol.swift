//
//  RepositoryServiceProtocol.swift
//  Core
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation

/// Protocol for managing repositories
public protocol RepositoryServiceProtocol {
    /// List all repositories
    /// - Returns: Array of repositories
    /// - Throws: Error if listing fails
    func listRepositories() async throws -> [Repository]
    
    /// Add a new repository
    /// - Parameter repository: Repository to add
    /// - Throws: Error if adding fails
    func addRepository(_ repository: Repository) async throws
    
    /// Remove a repository
    /// - Parameter repository: Repository to remove
    /// - Throws: Error if removal fails
    func removeRepository(_ repository: Repository) async throws
    
    /// Update a repository
    /// - Parameter repository: Repository to update
    /// - Throws: Error if update fails
    func updateRepository(_ repository: Repository) async throws
}
