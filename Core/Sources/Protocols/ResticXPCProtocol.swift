import Foundation

/// Protocol defining the XPC interface for Restic operations
@objc public protocol ResticXPCProtocol {
    /// Execute a Restic command
    /// - Parameters:
    ///   - command: The command to execute
    ///   - bookmark: Optional security-scoped bookmark for file access
    /// - Returns: Result of the command execution
    /// - Throws: SecurityError if execution fails
    @objc func executeCommand(_ command: String, withBookmark bookmark: Data?) async throws -> ProcessResult
    
    /// Validate the XPC service
    /// - Returns: true if service is valid and ready
    /// - Throws: SecurityError if validation fails
    @objc func validate() async throws -> Bool
    
    /// Health check ping
    /// - Throws: If the service is not responding
    @objc func ping() async throws
}
