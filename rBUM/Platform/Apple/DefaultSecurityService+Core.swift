import AppKit
import Core
import Foundation
import Security

/// Extension providing core security operations for DefaultSecurityService
public extension DefaultSecurityService {
    // MARK: - Core Operations

    /// Requests permission to access a specified URL.
    ///
    /// - Parameters:
    ///   - url: The URL for which permission is being requested
    ///   - message: Optional message to display in the permission dialog
    /// - Returns: Boolean indicating whether permission was granted
    func requestPermission(
        for url: URL,
        message: String? = nil
    ) async throws -> Bool {
        let id = UUID()
        let type: SecurityOperationType = .requestPermission

        return try await withOperation(id: id, type: type) {
            // Show permission dialog
            let panel = NSOpenPanel()
            panel.message = message ?? "Please grant access to this location"
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = url

            let response = await panel.beginSheetModal(for: NSApp.mainWindow ?? NSApp.keyWindow ?? NSWindow())
            return response == .OK
        }
    }

    /// Creates a security-scoped bookmark for the specified URL.
    ///
    /// - Parameter url: The URL for which to create a bookmark
    /// - Returns: Data representing the security-scoped bookmark
    func createBookmark(for url: URL) async throws -> Data {
        let id = UUID()
        let type: SecurityOperationType = .createBookmark

        return try await withOperation(id: id, type: type) {
            try await bookmarkService.createBookmark(for: url)
        }
    }

    /// Resolves a security-scoped bookmark to its URL.
    ///
    /// - Parameter bookmarkData: The bookmark data to resolve
    /// - Returns: The resolved URL
    func resolveBookmark(_ bookmarkData: Data) async throws -> URL {
        let id = UUID()
        let type: SecurityOperationType = .resolveBookmark

        return try await withOperation(id: id, type: type) {
            try await bookmarkService.resolveBookmark(bookmarkData)
        }
    }
}
