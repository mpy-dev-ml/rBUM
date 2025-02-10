import AppKit
import Core
import Foundation
import Security

/// Extension providing validation capabilities for DefaultSecurityService
public extension DefaultSecurityService {
    // MARK: - Validation

    /// Validates access to a directory.
    ///
    /// - Parameter url: The URL of the directory to validate
    /// - Returns: Boolean indicating whether access is valid
    func validateDirectoryAccess(at url: URL) async throws -> Bool {
        let id = UUID()
        let type: SecurityOperationType = .validateAccess

        return try await withOperation(id: id, type: type) {
            // Check directory permissions
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isReadableKey, .isWritableKey],
                options: [.skipsHiddenFiles]
            )

            // Check each item in directory
            for itemURL in contents {
                var isReadable: AnyObject?
                try itemURL.getResourceValue(&isReadable, forKey: .isReadableKey)

                var isWritable: AnyObject?
                try itemURL.getResourceValue(&isWritable, forKey: .isWritableKey)

                guard
                    isReadable as? Bool == true,
                    isWritable as? Bool == true
                else {
                    return false
                }
            }

            return true
        }
    }

    /// Validates sandbox container access.
    ///
    /// - Returns: Boolean indicating whether sandbox container access is valid
    func validateSandboxContainer() async throws -> Bool {
        let id = UUID()
        let type: SecurityOperationType = .validateContainer

        return try await withOperation(id: id, type: type) {
            // Get sandbox container
            guard let container = try? FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ) else {
                return false
            }

            // Validate container access
            return try validateDirectoryAccess(at: container)
        }
    }

    /// Validates security-scoped access to a URL.
    ///
    /// - Parameter url: The URL to validate
    /// - Returns: Boolean indicating whether security-scoped access is valid
    private func validateSecurityScopedAccess(to url: URL) async throws -> Bool {
        // Check if we have a security scoped bookmark
        guard let bookmark = try? await bookmarkService.findBookmark(for: url) else {
            return false
        }

        // Resolve bookmark to validate it
        _ = try await resolveBookmark(bookmark)
        return true
    }
}
