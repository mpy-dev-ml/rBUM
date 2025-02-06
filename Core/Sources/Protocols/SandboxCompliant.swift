//
//  SandboxCompliant.swift
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

/// Protocol defining sandbox compliance requirements
public protocol SandboxCompliant {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

public extension SandboxCompliant {
    /// Default implementation for safe resource access
    func withSafeAccess<T>(to url: URL, perform action: () throws -> T) throws -> T {
        guard startAccessing(url) else {
            throw SandboxError.accessDenied(url)
        }
        defer { stopAccessing(url) }
        return try action()
    }
    
    /// Default implementation for async safe resource access
    func withSafeAccess<T>(to url: URL, perform action: () async throws -> T) async throws -> T {
        guard startAccessing(url) else {
            throw SandboxError.accessDenied(url)
        }
        defer { stopAccessing(url) }
        return try await action()
    }
    
    /// Validate access to a URL
    func validateAccess(to url: URL) -> Bool {
        guard startAccessing(url) else {
            return false
        }
        stopAccessing(url)
        return true
    }
}
