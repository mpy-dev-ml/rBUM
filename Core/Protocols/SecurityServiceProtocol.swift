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
    /// Request permission to access a URL, ensuring sandbox compliance
    /// - Parameter url: The URL to request permission for
    /// - Returns: true if permission was granted and the security scope was established
    /// - Throws: SecurityError if permission cannot be requested or if sandbox violation occurs
    /// - Note: This operation is performed in the main app, not the XPC service
    func requestPermission(for url: URL) async throws -> Bool
    
    /// Create a security-scoped bookmark for persistent resource access
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: Bookmark data that can be persisted and shared with XPC service
    /// - Throws: SecurityError if bookmark creation fails or if URL is not accessible
    /// - Note: Bookmarks created here must be valid for use in the XPC service
    func createBookmark(for url: URL) async throws -> Data
    
    /// Resolve a security-scoped bookmark to regain resource access
    /// - Parameter bookmark: The bookmark data to resolve
    /// - Returns: Resolved URL with reestablished security scope
    /// - Throws: SecurityError if bookmark is stale or invalid
    /// - Note: Both main app and XPC service must be able to resolve these bookmarks
    func resolveBookmark(_ bookmark: Data) async throws -> URL
    
    /// Start accessing a security-scoped resource
    /// - Parameter url: The URL to start accessing
    /// - Returns: true if access was successfully started
    /// - Note: Must be balanced with a corresponding stopAccessing call
    /// - Important: Access must be properly coordinated between main app and XPC service
    func startAccessing(_ url: URL) -> Bool
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    /// - Note: Must be called after startAccessing when resource access is no longer needed
    /// - Important: Both main app and XPC service must properly release their access
    func stopAccessing(_ url: URL)
    
    /// Prepare URL and permissions for XPC service access
    /// - Parameter url: The URL to prepare
    /// - Returns: Data package containing necessary security information for XPC service
    /// - Throws: SecurityError if preparation fails
    /// - Note: This method ensures the XPC service can access the resource
    func prepareForXPCAccess(_ url: URL) async throws -> Data
    
    /// Validate XPC service connection and permissions
    /// - Returns: true if XPC service is properly configured and has necessary permissions
    /// - Throws: SecurityError if validation fails
    func validateXPCService() async throws -> Bool
}
