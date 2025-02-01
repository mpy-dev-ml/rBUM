import Foundation

/// Represents errors that can occur during Restic backup operations
public struct ResticBackupError: Error, Codable, Equatable {
    /// The type of backup error that occurred
    public let type: BackupErrorType
    /// Detailed error message
    public let message: String
    /// Optional underlying error details
    public let details: String?
    /// Timestamp when the error occurred
    public let timestamp: Date
    
    public init(
        type: BackupErrorType,
        message: String,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.message = message
        self.details = details
        self.timestamp = timestamp
    }
    
    /// Types of errors that can occur during Restic backup operations
    public enum BackupErrorType: String, Codable {
        /// Network-related errors (connection, timeout, etc.)
        case networkFailure
        /// Authentication or authorization failures
        case authenticationFailure
        /// Repository access or integrity issues
        case repositoryFailure
        /// File system access or permission issues
        case fileSystemFailure
        /// Insufficient system resources (disk space, memory)
        case resourceExhaustion
        /// Backup process was interrupted
        case operationInterrupted
        /// Repository lock could not be acquired
        case lockAcquisitionFailure
        /// Data integrity or corruption issues
        case dataIntegrityFailure
        /// Unexpected or unclassified errors
        case unclassifiedError
    }
}
