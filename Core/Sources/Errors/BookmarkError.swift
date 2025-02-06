//
//  BookmarkError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Errors that can occur during bookmark operations
public enum BookmarkError: LocalizedError {
    /// Failed to create a security-scoped bookmark
    case creationFailed(URL)
    
    /// Failed to resolve an existing bookmark
    case resolutionFailed(URL)
    
    /// Bookmark has become stale and needs to be recreated
    case staleBookmark(URL)
    
    /// Bookmark data is invalid or corrupted
    case invalidBookmark(URL)
    
    /// Access to the bookmarked resource was denied
    case accessDenied(URL)
    
    public var errorDescription: String? {
        switch self {
        case .creationFailed(let url):
            return "Failed to create security-scoped bookmark for \(url.path)"
        case .resolutionFailed(let url):
            return "Failed to resolve security-scoped bookmark for \(url.path)"
        case .staleBookmark(let url):
            return "Security-scoped bookmark is stale for \(url.path)"
        case .invalidBookmark(let url):
            return "Invalid security-scoped bookmark for \(url.path)"
        case .accessDenied(let url):
            return "Access denied to \(url.path)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .creationFailed(let url):
            return "The system was unable to create a security-scoped bookmark for the file or directory at \(url.path)"
        case .resolutionFailed(let url):
            return "The system was unable to resolve the security-scoped bookmark for \(url.path). The bookmark may be corrupted or the resource may have been moved."
        case .staleBookmark(let url):
            return "The security-scoped bookmark for \(url.path) has become stale. This can happen if the resource was moved or modified."
        case .invalidBookmark(let url):
            return "The security-scoped bookmark data for \(url.path) is invalid or corrupted."
        case .accessDenied(let url):
            return "The application does not have permission to access \(url.path). The user may need to grant access."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .creationFailed(let url):
            return "Please ensure the application has permission to access \(url.path) and try again."
        case .resolutionFailed(let url):
            return "Try recreating the bookmark for \(url.path). If the issue persists, the user may need to reselect the resource."
        case .staleBookmark(let url):
            return "Please recreate the bookmark for \(url.path) by requesting access again."
        case .invalidBookmark(let url):
            return "Please request access to \(url.path) again to create a new bookmark."
        case .accessDenied(let url):
            return "Please grant access to \(url.path) when prompted."
        }
    }
}
