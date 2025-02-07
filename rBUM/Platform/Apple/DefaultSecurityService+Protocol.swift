// 
//  DefaultSecurityService+Protocol.swift
//  rBUM
//
//  Created on 6 February 2025.
//

import AppKit
import Core
import Foundation

/// Extension to DefaultSecurityService implementing SecurityServiceProtocol methods
extension DefaultSecurityService {
    // MARK: - SecurityServiceProtocol Implementation

    /// Requests permission for the specified URL.
    ///
    /// This method will prompt the user to grant access to the specified URL.
    ///
    /// - Parameter url: The URL for which permission is being requested
    /// - Returns: `true` if permission is granted, `false` otherwise
    public func requestPermission(for url: URL) async throws -> Bool {
        try await measure("Request Permission") {
            // First check if we already have access
            if try await validateAccess(to: url) {
                return true
            }

            // Show open panel to request access
            let panel = await NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = url
            panel.message = "Please grant access to this location"
            panel.prompt = "Grant Access"

            let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())
            return response == .OK
        }
    }

    /// Creates a persistent bookmark for the specified URL.
    ///
    /// - Parameter url: The URL for which a bookmark is being created
    /// - Returns: The created bookmark data
    public func createBookmark(for url: URL) throws -> Data {
        try bookmarkService.createBookmark(for: url)
    }

    /// Resolves a bookmark to its corresponding URL.
    ///
    /// - Parameter bookmark: The bookmark data to resolve
    /// - Returns: The resolved URL
    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        try bookmarkService.resolveBookmark(bookmark)
    }

    /// Validates access to the specified URL.
    ///
    /// This method checks if the service has permission to access the specified URL.
    ///
    /// - Parameter url: The URL for which access is being validated
    /// - Returns: `true` if access is valid, `false` otherwise
    public func validateAccess(to url: URL) async throws -> Bool {
        try await measure("Validate Access") {
            do {
                let bookmark = try bookmarkService.createBookmark(for: url)
                return try bookmarkService.validateBookmark(bookmark)
            } catch {
                logger.error(
                    "Failed to validate access: \(error.localizedDescription)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return false
            }
        }
    }

    /// Starts accessing the specified URL.
    ///
    /// This method will attempt to start accessing the specified URL.
    ///
    /// - Parameter url: The URL for which access is being started
    /// - Returns: `true` if access is started successfully, `false` otherwise
    override public func startAccessing(_ url: URL) -> Bool {
        do {
            return try bookmarkService.startAccessing(url)
        } catch {
            logger.error(
                "Failed to start accessing: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
    }
}
