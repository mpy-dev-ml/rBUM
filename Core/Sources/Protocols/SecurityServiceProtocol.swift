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

/// A protocol that defines the interface for security-related operations in a sandboxed environment.
///
/// The `SecurityServiceProtocol` ensures proper handling of security-sensitive operations
/// within macOS's App Sandbox environment. Implementations must adhere to these requirements:
///
/// 1. Security-Scoped Bookmarks:
///    - Use bookmarks for persistent resource access
///    - Handle bookmark creation and resolution
///    - Manage bookmark expiration
///
/// 2. Resource Access:
///    - Properly start/stop resource access
///    - Handle permission requests
///    - Clean up resources appropriately
///
/// 3. XPC Integration:
///    - Coordinate with XPC service for command execution
///    - Never execute commands directly from main app
///    - Handle XPC connection failures
///
/// 4. Error Handling:
///    - Handle permission denials gracefully
///    - Manage bookmark staleness
///    - Handle resource access failures
///
/// Example usage:
/// ```swift
/// class SecurityManager: SecurityServiceProtocol {
///     func requestPermission(for url: URL) async throws -> Bool {
///         // Request user permission through system dialog
///         return try await showPermissionDialog(for: url)
///     }
///
///     func createBookmark(for url: URL) throws -> Data {
///         // Create a security-scoped bookmark
///         return try url.bookmarkData(options: .withSecurityScope)
///     }
/// }
/// ```
public protocol SecurityServiceProtocol {
    /// Requests permission to access a URL through the system's security mechanism.
    ///
    /// This method should:
    /// - Show the system permission dialog to the user
    /// - Handle user's response appropriately
    /// - Cache the permission if granted
    /// - Clean up if permission is denied
    ///
    /// - Parameter url: The URL for which to request permission
    /// - Returns: `true` if permission was granted, `false` otherwise
    /// - Throws: `SecurityError` if the permission request fails
    func requestPermission(for url: URL) async throws -> Bool
    
    /// Creates a security-scoped bookmark for persistent access to a URL.
    ///
    /// Security-scoped bookmarks allow an app to maintain access to user-selected
    /// resources across app launches. This method should:
    /// - Verify current access permissions
    /// - Create a bookmark with appropriate security options
    /// - Handle bookmark creation failures
    ///
    /// - Parameter url: The URL for which to create a bookmark
    /// - Returns: The bookmark data for persistent access
    /// - Throws: `SecurityError` if bookmark creation fails
    func createBookmark(for url: URL) throws -> Data
    
    /// Resolves a security-scoped bookmark back to its URL.
    ///
    /// This method should:
    /// - Validate the bookmark data
    /// - Handle stale bookmarks
    /// - Update bookmarks when needed
    /// - Verify resolved URL accessibility
    ///
    /// - Parameter bookmark: The bookmark data to resolve
    /// - Returns: The resolved URL
    /// - Throws: `SecurityError` if bookmark resolution fails
    func resolveBookmark(_ bookmark: Data) throws -> URL
    
    /// Begins accessing a security-scoped resource.
    ///
    /// This method must be called before attempting to access any security-scoped
    /// resource. It should:
    /// - Verify bookmark validity
    /// - Start resource access
    /// - Handle access denials
    /// - Track active access sessions
    ///
    /// - Parameter url: The URL to start accessing
    /// - Returns: `true` if access was successfully started
    /// - Throws: `SecurityError` if access cannot be started
    func startAccessing(_ url: URL) throws -> Bool
    
    /// Stops accessing a security-scoped resource.
    ///
    /// This method must be called after finishing access to a security-scoped
    /// resource. It should:
    /// - Stop resource access
    /// - Clean up resources
    /// - Update access tracking
    /// - Handle cleanup failures
    ///
    /// - Parameter url: The URL to stop accessing
    /// - Throws: `SecurityError` if access cannot be stopped properly
    func stopAccessing(_ url: URL) async throws
    
    /// Validates whether access to a URL is currently granted.
    ///
    /// This method should:
    /// - Check current permissions
    /// - Verify bookmark validity
    /// - Test resource accessibility
    /// - Handle validation failures
    ///
    /// - Parameter url: The URL to validate access for
    /// - Returns: `true` if access is currently granted
    /// - Throws: `SecurityError` if validation fails
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
