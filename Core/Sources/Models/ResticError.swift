//
//  ResticError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Error codes for Restic backup operations
@objc public enum ResticBackupErrorCode: Int {
    case repositoryNotFound = 1
    case invalidCredentials = """
        The provided credentials are invalid. \
        Please check your repository password \
        and try again.
        """
    case backupFailed = """
        The backup operation failed. \
        Please check the logs for more details.
        """
    case restoreFailed = 4
    case snapshotFailed = 5
    case initializationFailed = 6
    case permissionDenied = 7
    case networkError = 8
    case unknownError = 9
    case invalidRepositoryStructure = 10
}

/// Represents errors that can occur during Restic backup operations
@objc public class ResticBackupError: NSError {
    /// Domain identifier for Restic backup errors
    public static let domain = "dev.mpy.rBUM.ResticBackup"
    
    /// Creates a new ResticBackupError with the specified code and message
    /// - Parameters:
    ///   - code: The error code indicating the type of error
    ///   - message: A user-friendly description of the error
    ///   - details: Optional additional details about the error
    /// - Returns: A configured ResticBackupError instance
    public static func error(
        code: ResticBackupErrorCode,
        message: String,
        details: String? = nil
    ) -> ResticBackupError {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: message
        ]
        
        if let details = details {
            userInfo["details"] = details
        }
        
        return ResticBackupError(
            domain: domain,
            code: code.rawValue,
            userInfo: userInfo
        )
    }
    
    public var errorDetails: String? {
        return userInfo["details"] as? String
    }
}

/// Error type for Restic command operations
@objc public enum ResticError: Int, LocalizedError {
    case invalidCommand = 1
    case invalidWorkingDirectory = 2
    case invalidBookmark = 3
    case accessDenied = 4
    case resourceError = 5
    case unknownError = 6
    case compressionError(String)
    case insufficientDiskSpace(required: UInt64, available: UInt64)
    case invalidConfiguration(String)
    case invalidCredentials(String)
    case invalidPath(String)
    case invalidSettings(String)
    case invalidSnapshotId(String)
    case invalidTag(String)
    case lockError(String)
    case networkError(String)
    case repositoryExists
    case repositoryNotFound
    case resticNotInstalled
    case snapshotNotFound(String)
    case unexpectedError(String)
    
    public var errorDescription: String? {
        switch self {
        case .compressionError(let message):
            return "Compression error: \(message)"
        case .insufficientDiskSpace(let required, let available):
            return "Insufficient disk space - Required: \(required) bytes, Available: \(available) bytes"
        case .invalidCommand:
            return "Invalid command"
        case .invalidWorkingDirectory:
            return "Invalid working directory"
        case .invalidBookmark:
            return "Invalid security-scoped bookmark"
        case .accessDenied:
            return "Access denied"
        case .resourceError:
            return "Resource error"
        case .unknownError:
            return "Unknown error"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .invalidCredentials(let message):
            return "Invalid credentials: \(message)"
        case .invalidPath(let message):
            return "Invalid path: \(message)"
        case .invalidSettings(let message):
            return "Invalid settings: \(message)"
        case .invalidSnapshotId(let message):
            return "Invalid snapshot ID: \(message)"
        case .invalidTag(let message):
            return "Invalid tag: \(message)"
        case .lockError(let message):
            return "Lock error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .repositoryExists:
            return "Repository already exists"
        case .repositoryNotFound:
            return "Repository not found"
        case .resticNotInstalled:
            return "Restic is not installed"
        case .snapshotNotFound(let message):
            return "Snapshot not found: \(message)"
        case .unexpectedError(let message):
            return "Unexpected error: \(message)"
        }
    }
    
    public static func error(_ code: ResticError, _ message: String) -> NSError {
        return NSError(
            domain: "dev.mpy.rBUM.Restic",
            code: code.rawValue,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
