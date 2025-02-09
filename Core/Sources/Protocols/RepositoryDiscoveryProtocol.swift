import Foundation

/// Protocol defining the interface for repository discovery operations
///
/// This protocol defines the core operations needed to discover, verify, and index
/// Restic repositories on the filesystem. It is designed to work with the sandbox
/// restrictions of macOS applications and uses async/await for all operations
/// that may take significant time.
///
/// ## Overview
/// The repository discovery process consists of three main phases:
/// 1. Scanning: Finding potential repositories in the filesystem
/// 2. Verification: Confirming that found locations are valid repositories
/// 3. Indexing: Processing repositories for searching and management
///
/// ## Implementation Notes
/// Implementations of this protocol should:
/// - Handle sandbox restrictions appropriately
/// - Use security-scoped bookmarks for persistent access
/// - Implement proper error handling
/// - Support operation cancellation
/// - Clean up resources properly
///
/// ## Example Usage
/// ```swift
/// let service = RepositoryDiscoveryService()
/// 
/// // Start scanning
/// let repositories = try await service.scanLocation(url, recursive: true)
/// 
/// // Verify and index each repository
/// for repository in repositories {
///     guard try await service.verifyRepository(repository) else { continue }
///     try await service.indexRepository(repository)
/// }
/// ```
///
/// ## Topics
/// ### Discovering Repositories
/// - ``scanLocation(_:recursive:)``
///
/// ### Managing Repositories
/// - ``verifyRepository(_:)``
/// - ``indexRepository(_:)``
///
/// ### Cancellation
/// - ``cancelDiscovery()``
public protocol RepositoryDiscoveryProtocol {
    /// Scans a specific URL for Restic repositories
    /// - Parameters:
    ///   - url: The URL to scan
    ///   - recursive: Whether to scan subdirectories
    /// - Returns: An array of discovered repositories
    /// - Throws: `RepositoryDiscoveryError` if scanning fails
    func scanLocation(_ url: URL, recursive: Bool) async throws -> [DiscoveredRepository]
    
    /// Verifies if a discovered repository is valid
    /// - Parameter repository: The repository to verify
    /// - Returns: A boolean indicating if the repository is valid
    /// - Throws: `RepositoryDiscoveryError` if verification fails
    func verifyRepository(_ repository: DiscoveredRepository) async throws -> Bool
    
    /// Indexes a verified repository for searching
    /// - Parameter repository: The repository to index
    /// - Throws: `RepositoryDiscoveryError` if indexing fails
    func indexRepository(_ repository: DiscoveredRepository) async throws
    
    /// Cancels any ongoing discovery operations
    func cancelDiscovery()
}
