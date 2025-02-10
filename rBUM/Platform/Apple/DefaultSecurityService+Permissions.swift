import AppKit
import Core
import Foundation

extension DefaultSecurityService {
    // MARK: - Permission Management

    /// Requests permission to access a resource.
    ///
    /// - Parameter url: The URL of the resource to request permission for
    /// - Returns: True if permission was granted
    /// - Throws: SecurityError if permission request fails
    func requestPermission(for url: URL) async throws -> Bool {
        // Create operation ID
        let operationId = UUID()

        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .permissionRequest,
                url: url
            )

            // Check if we already have permission
            if try await validateAccess(to: url) {
                // Complete operation
                try await completeSecurityOperation(operationId, success: true)
                return true
            }

            // Request permission via open panel
            let granted = try await requestPermissionViaPanel(for: url)

            if granted {
                // Create bookmark if permission granted
                _ = try await createSecurityBookmark(for: url)
            }

            // Complete operation
            try await completeSecurityOperation(operationId, success: granted)

            return granted

        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }

    /// Requests permission via an open panel.
    ///
    /// - Parameter url: The URL to request permission for
    /// - Returns: True if permission was granted
    /// - Throws: SecurityError if panel cannot be shown
    private func requestPermissionViaPanel(for url: URL) async throws -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.canChooseFiles = !url.hasDirectoryPath
                panel.canChooseDirectories = url.hasDirectoryPath
                panel.allowsMultipleSelection = false
                panel.directoryURL = url
                panel.message = "Please grant access to: \(url.path)"

                panel.begin { response in
                    if response == .OK,
                       let selectedURL = panel.url,
                       selectedURL == url
                    {
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    /// Revokes permission to access a resource.
    ///
    /// - Parameter url: The URL of the resource to revoke permission for
    /// - Throws: SecurityError if permission revocation fails
    func revokePermission(for url: URL) async throws {
        // Create operation ID
        let operationId = UUID()

        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .permissionRevocation,
                url: url
            )

            // Stop accessing resource
            try await stopAccessingResource(url)

            // Delete bookmark
            try await deleteSecurityBookmark(for: url)

            // Complete operation
            try await completeSecurityOperation(operationId, success: true)

        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }

    /// Checks if we have permission to access a resource.
    ///
    /// - Parameter url: The URL of the resource to check
    /// - Returns: True if we have permission
    /// - Throws: SecurityError if check fails
    func hasPermission(for url: URL) async throws -> Bool {
        // Create operation ID
        let operationId = UUID()

        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .permissionCheck,
                url: url
            )

            // Check permission
            let hasPermission = try await validateAccess(to: url)

            // Complete operation
            try await completeSecurityOperation(operationId, success: true)

            return hasPermission

        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }

    /// Updates permissions for a resource.
    ///
    /// - Parameters:
    ///   - url: The URL of the resource to update permissions for
    ///   - newURL: The new URL to update permissions for
    /// - Throws: SecurityError if permission update fails
    func updatePermission(for url: URL, with newURL: URL) async throws {
        // Create operation ID
        let operationId = UUID()

        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .permissionUpdate,
                url: url
            )

            // Stop accessing old resource
            try await stopAccessingResource(url)

            // Request permission for new resource
            guard try await requestPermission(for: newURL) else {
                throw SecurityError.permissionDenied("Permission denied for new URL")
            }

            // Update bookmark
            try await updateSecurityBookmark(for: url, with: newURL)

            // Complete operation
            try await completeSecurityOperation(operationId, success: true)

        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }
}
