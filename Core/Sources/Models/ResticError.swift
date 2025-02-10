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
            NSLocalizedDescriptionKey: message,
        ]

        if let details {
            userInfo["details"] = details
        }

        return ResticBackupError(
            domain: domain,
            code: code.rawValue,
            userInfo: userInfo
        )
    }

    public var errorDetails: String? {
        userInfo["details"] as? String
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
        case let .compressionError(message):
            "Compression error: \(message)"
        case let .insufficientDiskSpace(required, available):
            "Insufficient disk space - Required: \(required) bytes, Available: \(available) bytes"
        case .invalidCommand:
            "Invalid command"
        case .invalidWorkingDirectory:
            "Invalid working directory"
        case .invalidBookmark:
            "Invalid security-scoped bookmark"
        case .accessDenied:
            "Access denied"
        case .resourceError:
            "Resource error"
        case .unknownError:
            "Unknown error"
        case let .invalidConfiguration(message):
            "Invalid configuration: \(message)"
        case let .invalidCredentials(message):
            "Invalid credentials: \(message)"
        case let .invalidPath(message):
            "Invalid path: \(message)"
        case let .invalidSettings(message):
            "Invalid settings: \(message)"
        case let .invalidSnapshotId(message):
            "Invalid snapshot ID: \(message)"
        case let .invalidTag(message):
            "Invalid tag: \(message)"
        case let .lockError(message):
            "Lock error: \(message)"
        case let .networkError(message):
            "Network error: \(message)"
        case .repositoryExists:
            "Repository already exists"
        case .repositoryNotFound:
            "Repository not found"
        case .resticNotInstalled:
            "Restic is not installed"
        case let .snapshotNotFound(message):
            "Snapshot not found: \(message)"
        case let .unexpectedError(message):
            "Unexpected error: \(message)"
        }
    }

    public static func error(_ code: ResticError, _ message: String) -> NSError {
        NSError(
            domain: "dev.mpy.rBUM.Restic",
            code: code.rawValue,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
