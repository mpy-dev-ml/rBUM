//
//  RepositoryStorageProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Protocol for managing repository persistence
public protocol RepositoryStorageProtocol {
    /// Save a repository to persistent storage
    /// - Parameter repository: Repository to save
    /// - Throws: SecurityError if save fails
    func saveRepository(_ repository: Repository) async throws
    
    /// Get all stored repositories
    /// - Returns: Array of stored repositories
    /// - Throws: SecurityError if retrieval fails
    func getRepositories() async throws -> [Repository]
    
    /// Delete a repository from persistent storage
    /// - Parameter repository: Repository to delete
    /// - Throws: SecurityError if deletion fails
    func deleteRepository(_ repository: Repository) async throws
}
