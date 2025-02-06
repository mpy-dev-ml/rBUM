//
//  SecurityError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Errors that can occur during security operations
public enum SecurityError: LocalizedError, Equatable {
    case permissionDenied(String)
    case bookmarkCreationFailed(String)
    case bookmarkResolutionFailed(String)
    case bookmarkStale(String)
    case sandboxViolation(String)
    case accessDenied(String)
    case resourceUnavailable(String)
    case xpcConnectionFailed(String)
    case xpcServiceError(String)
    case xpcPermissionDenied(String)
    case xpcValidationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .bookmarkCreationFailed(let message):
            return "Failed to create bookmark: \(message)"
        case .bookmarkResolutionFailed(let message):
            return "Failed to resolve bookmark: \(message)"
        case .bookmarkStale(let message):
            return "Bookmark is stale: \(message)"
        case .sandboxViolation(let message):
            return "Sandbox violation: \(message)"
        case .accessDenied(let message):
            return "Access denied: \(message)"
        case .resourceUnavailable(let message):
            return "Resource unavailable: \(message)"
        case .xpcConnectionFailed(let message):
            return "XPC connection failed: \(message)"
        case .xpcServiceError(let message):
            return "XPC service error: \(message)"
        case .xpcPermissionDenied(let message):
            return "XPC permission denied: \(message)"
        case .xpcValidationFailed(let message):
            return "XPC validation failed: \(message)"
        }
    }
}
