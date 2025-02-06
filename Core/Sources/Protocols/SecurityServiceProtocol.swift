//
//  SecurityServiceProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Protocol defining security operations with sandbox compliance
///
/// This protocol defines the interface for security-related operations that must be performed
/// within the app sandbox. All implementations must:
/// 1. Use security-scoped bookmarks for persistent resource access
/// 2. Properly start/stop resource access
/// 3. Handle permission expiration and renewal
/// 4. Clean up resources when access is no longer needed
/// 5. Coordinate with XPC service for command execution
/// 6. Never execute commands directly from the main app
public protocol SecurityServiceProtocol {
    /// Request permission to access a URL
    /// - Parameter url: The URL to request permission for
    /// - Returns: true if permission was granted
    /// - Throws: SecurityError if permission request fails
    func requestPermission(for url: URL) async throws -> Bool
    
    /// Create a security-scoped bookmark for a URL
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: Bookmark data for persistent access
    /// - Throws: SecurityError if bookmark creation fails
    func createBookmark(for url: URL) throws -> Data
    
    /// Resolve a security-scoped bookmark to a URL
    /// - Parameter bookmark: The bookmark data to resolve
    /// - Returns: The resolved URL
    /// - Throws: SecurityError if bookmark resolution fails
    func resolveBookmark(_ bookmark: Data) throws -> URL
    
    /// Start accessing a security-scoped resource
    /// - Parameter url: The URL to start accessing
    /// - Returns: true if access was successfully started
    /// - Throws: SecurityError if access cannot be started
    func startAccessing(_ url: URL) throws -> Bool
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    /// - Throws: SecurityError if access cannot be stopped
    func stopAccessing(_ url: URL) async throws
    
    /// Validate access to a URL, ensuring sandbox compliance
    /// - Parameter url: The URL to validate access for
    /// - Returns: true if access is valid and the security scope is established
    /// - Throws: SecurityError if access cannot be validated or if sandbox violation occurs
    func validateAccess(to url: URL) async throws -> Bool
    
    /// Persist access to a URL by creating a security-scoped bookmark
    /// - Parameter url: The URL to persist access for
    /// - Returns: The bookmark data that can be used to restore access
    /// - Throws: SecurityError if access cannot be persisted
    func persistAccess(to url: URL) async throws -> Data
    
    /// Validate XPC connection security
    /// - Parameter connection: The XPC connection to validate
    /// - Returns: true if connection is secure and valid
    /// - Throws: SecurityError if validation fails or security requirements are not met
    func validateXPCConnection(_ connection: NSXPCConnection) async throws -> Bool
    
    /// Validate the XPC service connection
    /// - Returns: true if the XPC service is available and has necessary permissions
    /// - Throws: SecurityError if XPC service is unavailable or lacks permissions
    func validateXPCService() async throws -> Bool
}
