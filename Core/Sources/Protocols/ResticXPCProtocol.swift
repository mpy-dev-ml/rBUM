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
    
    /// Initialize a Restic repository
    /// - Parameters:
    ///   - repository: URL of the repository to initialize
    ///   - password: Repository password
    /// - Throws: SecurityError if initialization fails
    @objc func initialize(repository: URL, password: String) async throws
    
    /// Backup files to a Restic repository
    /// - Parameters:
    ///   - source: Source directory to backup
    ///   - repository: Target repository URL
    /// - Throws: SecurityError if backup fails
    @objc func backup(source: URL, repository: URL) async throws
    
    /// Restore files from a Restic repository
    /// - Parameters:
    ///   - repository: Source repository URL
    ///   - snapshot: Snapshot ID to restore from
    ///   - destination: Destination directory
    /// - Throws: SecurityError if restore fails
    @objc func restore(repository: URL, snapshot: String, destination: URL) async throws
    
    /// List snapshots in a repository
    /// - Parameter repository: Repository URL
    /// - Returns: Array of snapshots
    /// - Throws: SecurityError if listing fails
    @objc func listSnapshots(repository: URL) async throws -> NSArray
    
    /// Get the current connection state
    /// - Returns: true if the connection is active and ready
    /// - Throws: SecurityError if state check fails
    @objc func getConnectionState() async throws -> Bool
    
    /// Validate permissions and access
    /// - Returns: true if all permissions are valid
    /// - Throws: SecurityError if validation fails
    @objc func validatePermissions() async throws -> Bool
    
    /// Health check ping
    /// - Throws: If the service is not responding
    @objc func ping() async throws
}
