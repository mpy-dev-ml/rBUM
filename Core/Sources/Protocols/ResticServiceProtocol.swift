import Foundation

/// Protocol for executing restic commands via XPC
@objc public protocol ResticServiceProtocol {
    /// Execute a restic command
    /// - Parameter command: The command to execute
    /// - Returns: The result of the command execution
    /// - Throws: Error if the command fails
    func executeCommand(_ command: String) async throws -> ProcessResult
}
