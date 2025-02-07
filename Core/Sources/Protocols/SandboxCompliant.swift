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

/// A protocol that defines the requirements for sandbox-compliant file access in macOS applications.
///
/// The `SandboxCompliant` protocol ensures that types implementing it properly handle
/// file access within the macOS App Sandbox environment. This includes:
/// - Managing security-scoped bookmarks
/// - Properly starting and stopping file access
/// - Handling access denials gracefully
/// - Maintaining minimal access duration
///
/// Example usage:
/// ```swift
/// class FileManager: SandboxCompliant {
///     func startAccessing(_ url: URL) -> Bool {
///         return url.startAccessingSecurityScopedResource()
///     }
///
///     func stopAccessing(_ url: URL) {
///         url.stopAccessingSecurityScopedResource()
///     }
/// }
/// ```
public protocol SandboxCompliant {
    /// Begins accessing a security-scoped resource.
    ///
    /// This method should be called before attempting to access any security-scoped resource.
    /// It ensures proper sandbox compliance by explicitly requesting access to the resource.
    ///
    /// - Parameter url: The URL of the security-scoped resource to access
    /// - Returns: `true` if access was granted, `false` otherwise
    func startAccessing(_ url: URL) -> Bool

    /// Stops accessing a security-scoped resource.
    ///
    /// This method should be called after you're finished accessing the security-scoped resource.
    /// It's crucial to call this method to release the resource and maintain minimal access duration.
    ///
    /// - Parameter url: The URL of the security-scoped resource to stop accessing
    func stopAccessing(_ url: URL)
}

public extension SandboxCompliant {
    /// Safely performs an action with a security-scoped resource.
    ///
    /// This method provides a convenient way to work with security-scoped resources by:
    /// - Automatically starting access to the resource
    /// - Executing the provided action
    /// - Ensuring the resource is released using defer
    /// - Handling access denial appropriately
    ///
    /// Example usage:
    /// ```swift
    /// try fileManager.withSafeAccess(to: fileURL) {
    ///     try FileManager.default.copyItem(at: fileURL, to: destinationURL)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - url: The URL of the security-scoped resource to access
    ///   - action: A closure that performs operations on the resource
    /// - Returns: The result of the action
    /// - Throws: `SandboxError.accessDenied` if access is denied, or any error thrown by the action
    func withSafeAccess<T>(to url: URL, perform action: () throws -> T) throws -> T {
        guard startAccessing(url) else {
            throw SandboxError.accessDenied(url)
        }
        defer { stopAccessing(url) }
        return try action()
    }
    
    /// Safely performs an asynchronous action with a security-scoped resource.
    ///
    /// This method provides a convenient way to work with security-scoped resources by:
    /// - Automatically starting access to the resource
    /// - Executing the provided asynchronous action
    /// - Ensuring the resource is released using defer
    /// - Handling access denial appropriately
    ///
    /// Example usage:
    /// ```swift
    /// try await fileManager.withSafeAccess(to: fileURL) {
    ///     try await FileManager.default.copyItem(at: fileURL, to: destinationURL)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - url: The URL of the security-scoped resource to access
    ///   - action: An asynchronous closure that performs operations on the resource
    /// - Returns: The result of the action
    /// - Throws: `SandboxError.accessDenied` if access is denied, or any error thrown by the action
    func withSafeAccess<T>(to url: URL, perform action: () async throws -> T) async throws -> T {
        guard startAccessing(url) else {
            throw SandboxError.accessDenied(url)
        }
        defer { stopAccessing(url) }
        return try await action()
    }
    
    /// Validate access to a URL
    ///
    /// This method checks if access to a URL is granted.
    ///
    /// - Parameter url: The URL to validate access for
    /// - Returns: `true` if access is granted, `false` otherwise
    func validateAccess(to url: URL) -> Bool {
        guard startAccessing(url) else {
            return false
        }
        stopAccessing(url)
        return true
    }
}
