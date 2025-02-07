//
//  SecurityError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Errors that can occur during security operations
public enum SecurityError: LocalizedError, Equatable {
    /// Access permission was denied by the system
    case permissionDenied(String)
    /// Failed to create a security-scoped bookmark
    case bookmarkCreationFailed(String)
    /// Failed to resolve an existing security-scoped bookmark
    case bookmarkResolutionFailed(String)
    /// Security-scoped bookmark has become stale and needs to be recreated
    case bookmarkStale(String)
    /// Operation violates sandbox restrictions
    case sandboxViolation(String)
    /// Access to a resource was denied
    case accessDenied(String)
    /// Required resource is not available or accessible
    case resourceUnavailable(String)
    /// Failed to establish XPC connection
    case xpcConnectionFailed(String)
    /// XPC service encountered an error during operation
    case xpcServiceError(String)
    /// XPC service denied permission for the requested operation
    case xpcPermissionDenied(String)
    /// XPC message validation failed
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
