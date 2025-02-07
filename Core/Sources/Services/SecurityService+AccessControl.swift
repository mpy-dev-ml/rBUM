import AppKit
import Foundation

extension SecurityService {
    // MARK: - Access Control
    
    /// Request user permission to access a URL through a system dialog
    /// - Parameter url: URL to request permission for
    /// - Returns: True if permission was granted, false otherwise
    @MainActor
    public func requestPermission(for url: URL) async throws -> Bool {
        logger.debug(
            "Requesting permission for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = url
        panel.message = "Please grant access to this location"
        panel.prompt = "Grant Access"

        let response = await panel.beginSheetModal(
            for: NSApp.keyWindow ?? NSWindow(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
        )

        if response == .OK {
            logger.debug(
                "Permission granted for: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            return true
        } else {
            logger.debug(
                "Permission denied for: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
    }
    
    /// Start accessing a security-scoped URL
    /// - Parameter url: URL to start accessing
    /// - Returns: True if access was started successfully
    /// - Throws: SecurityError if access cannot be started
    public func startAccessing(_ url: URL) throws -> Bool {
        logger.debug(
            "Starting access for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )
        return url.startAccessingSecurityScopedResource()
    }

    /// Stop accessing a security-scoped URL
    /// - Parameter url: URL to stop accessing
    /// - Throws: SecurityError if access cannot be stopped
    public func stopAccessing(_ url: URL) async throws {
        logger.debug(
            "Stopping access for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )
        url.stopAccessingSecurityScopedResource()
    }

    /// Validate access to a URL by attempting to create and resolve a bookmark
    /// - Parameter url: URL to validate access for
    /// - Returns: True if access is valid
    /// - Throws: SecurityError if validation fails
    public func validateAccess(to url: URL) async throws -> Bool {
        logger.debug(
            "Validating access to: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        do {
            let bookmark = try createBookmark(for: url)
            let resolvedURL = try resolveBookmark(bookmark)
            return resolvedURL.path == url.path
        } catch {
            return false
        }
    }
}
