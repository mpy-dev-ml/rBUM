import AppKit
import Core
import Foundation
import Security

/// Extension providing security check capabilities for DefaultSecurityService
public extension DefaultSecurityService {
    // MARK: - Security Checks

    /// Checks if security-scoped access is available for a URL.
    ///
    /// - Parameter url: The URL to check
    /// - Returns: Boolean indicating whether security-scoped access is available
    private func checkSecurityScopedAccess(to url: URL) async throws -> Bool {
        // Check if we have a security scoped bookmark
        guard let bookmark = try? await bookmarkService.findBookmark(for: url) else {
            return false
        }

        // Check if bookmark is valid
        guard let resolvedURL = try? await resolveBookmark(bookmark) else {
            return false
        }

        // Check if resolved URL matches original
        return resolvedURL == url
    }

    /// Checks if a URL requires security-scoped access.
    ///
    /// - Parameter url: The URL to check
    /// - Returns: Boolean indicating whether security-scoped access is required
    func requiresSecurityScopedAccess(_ url: URL) -> Bool {
        // Check if URL is within sandbox container
        guard let container = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return true
        }

        // If URL is within container, no security-scoped access needed
        return !url.path.hasPrefix(container.path)
    }

    /// Checks if the service has permission to access a URL.
    ///
    /// - Parameter url: The URL to check
    /// - Returns: Boolean indicating whether permission is available
    func hasPermission(for url: URL) async throws -> Bool {
        let id = UUID()
        let type: SecurityOperationType = .checkPermission

        return try await withOperation(id: id, type: type) {
            // If URL doesn't require security-scoped access, we have permission
            guard requiresSecurityScopedAccess(url) else {
                return true
            }

            // Check for security-scoped access
            return try await checkSecurityScopedAccess(to: url)
        }
    }
}
