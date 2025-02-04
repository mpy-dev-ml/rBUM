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
    /// Validate access to a URL, ensuring sandbox compliance
    /// - Parameter url: The URL to validate access for
    /// - Returns: true if access is valid and the security scope is established
    /// - Throws: SecurityError if access cannot be validated or if sandbox violation occurs
    func validateAccess(to url: URL) async throws -> Bool
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    /// - Throws: SecurityError if access cannot be stopped
    func stopAccessing(_ url: URL) async throws
    
    /// Persist access to a URL by creating a security-scoped bookmark
    /// - Parameter url: The URL to persist access for
    /// - Returns: The bookmark data that can be used to restore access
    /// - Throws: SecurityError if bookmark cannot be created
    func persistAccess(to url: URL) async throws -> Data
    
    /// Validate the XPC service connection
    /// - Returns: true if the XPC service is available and has necessary permissions
    /// - Throws: SecurityError if XPC service is unavailable or lacks permissions
    func validateXPCService() async throws -> Bool
}
