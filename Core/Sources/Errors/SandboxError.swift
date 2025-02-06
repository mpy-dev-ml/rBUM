//
//  SandboxError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Errors related to sandbox operations
public enum SandboxError: LocalizedError {
    case accessDenied(URL)
    case bookmarkInvalid(URL)
    case bookmarkCreationFailed(URL)
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied(let url):
            return "Access denied to \(url.path)"
        case .bookmarkInvalid(let url):
            return "Invalid bookmark for \(url.path)"
        case .bookmarkCreationFailed(let url):
            return "Failed to create bookmark for \(url.path)"
        }
    }
}

public extension Error {
    /// Convert any error to a user-presentable format
    var userDescription: String {
        switch self {
        case let error as LocalizedError:
            return error.localizedDescription
        default:
            return localizedDescription
        }
    }
}