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
    case invalidCredentials = 2
    case backupFailed = 3
    case restoreFailed = 4
    case snapshotFailed = 5
    case initializationFailed = 6
    case permissionDenied = 7
    case networkError = 8
    case unknownError = 9
}

/// Represents errors that can occur during Restic backup operations
@objc public class ResticBackupError: NSError {
    public static let domain = "dev.mpy.rBUM.ResticBackup"
    
    public static func error(code: ResticBackupErrorCode, message: String, details: String? = nil) -> ResticBackupError {
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
    
    public var errorDescription: String? {
        switch self {
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
