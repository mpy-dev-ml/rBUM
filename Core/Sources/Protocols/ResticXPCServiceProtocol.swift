import Foundation

/// Protocol defining the XPC service interface for executing Restic commands
///
/// This protocol defines the communication interface between the main sandboxed app
/// and the XPC service that executes Restic commands. The XPC service must:
/// 1. Handle command execution outside the sandbox
/// 2. Properly manage security-scoped bookmarks
/// 3. Clean up resources after command execution
/// 4. Handle permission validation
@objc public protocol ResticXPCServiceProtocol: NSObjectProtocol {
    /// Establish connection with the XPC service
    /// - Throws: SecurityError if connection fails
    @objc func connect() async throws
    
    /// Execute a Restic command through the XPC service
    /// - Parameters:
    ///   - command: The command to execute
    ///   - bookmark: Optional security-scoped bookmark for file access
    /// - Returns: Result of the command execution
    /// - Throws: SecurityError if execution fails or permissions are invalid
    @objc func executeCommand(_ command: String, withBookmark bookmark: Data?) async throws -> ProcessResult
    
    /// Start accessing a security-scoped resource in the XPC service
    /// - Parameter url: The URL to start accessing
    /// - Returns: true if access was successfully started
    /// - Note: Must be balanced with a corresponding stopAccessing call
    @objc func startAccessing(_ url: URL) -> Bool
    
    /// Stop accessing a security-scoped resource in the XPC service
    /// - Parameter url: The URL to stop accessing
    /// - Note: Must be called after startAccessing when resource access is no longer needed
    @objc func stopAccessing(_ url: URL)
    
    /// Validate that the XPC service has necessary permissions
    /// - Returns: true if all permissions are valid
    /// - Throws: SecurityError if validation fails
    @objc func validatePermissions() async throws -> Bool
}
