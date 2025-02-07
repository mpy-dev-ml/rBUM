import AppKit
import Core
import Foundation

extension DefaultSecurityService {
    // MARK: - Access Control
    
    /// Starts accessing a security-scoped resource.
    ///
    /// - Parameter url: The URL of the resource to access
    /// - Returns: True if access was successfully started
    /// - Throws: SecurityError if access cannot be started
    func startAccessingResource(_ url: URL) async throws -> Bool {
        // Create operation ID
        let operationId = UUID()
        
        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .accessStart,
                url: url
            )
            
            // Check if we have a security-scoped bookmark
            guard try await checkSecurityScopedAccess(to: url) else {
                throw SecurityError.accessDenied("No security-scoped access available")
            }
            
            // Start accessing resource
            guard url.startAccessingSecurityScopedResource() else {
                throw SecurityError.accessDenied("Failed to start accessing resource")
            }
            
            // Complete operation
            try await completeSecurityOperation(operationId, success: true)
            
            return true
            
        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Stops accessing a security-scoped resource.
    ///
    /// - Parameter url: The URL of the resource to stop accessing
    /// - Throws: SecurityError if access cannot be stopped
    func stopAccessingResource(_ url: URL) async throws {
        // Create operation ID
        let operationId = UUID()
        
        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .accessStop,
                url: url
            )
            
            // Stop accessing resource
            url.stopAccessingSecurityScopedResource()
            
            // Complete operation
            try await completeSecurityOperation(operationId, success: true)
            
        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Validates access to a security-scoped resource.
    ///
    /// - Parameter url: The URL of the resource to validate
    /// - Returns: True if access is valid
    /// - Throws: SecurityError if validation fails
    func validateAccess(to url: URL) async throws -> Bool {
        // Create operation ID
        let operationId = UUID()
        
        do {
            // Start operation
            try await startSecurityOperation(
                operationId,
                type: .accessValidation,
                url: url
            )
            
            // Check sandbox container access
            guard try await validateSandboxAccess() else {
                throw SecurityError.accessDenied("No sandbox container access")
            }
            
            // Check security-scoped access
            guard try await checkSecurityScopedAccess(to: url) else {
                throw SecurityError.accessDenied("No security-scoped access")
            }
            
            // Validate directory access if applicable
            if url.hasDirectoryPath {
                guard try validateDirectoryAccess(at: url) else {
                    throw SecurityError.accessDenied("Invalid directory access")
                }
            }
            
            // Complete operation
            try await completeSecurityOperation(operationId, success: true)
            
            return true
            
        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Checks if we have security-scoped access to a resource.
    ///
    /// - Parameter url: The URL of the resource to check
    /// - Returns: True if we have security-scoped access
    /// - Throws: SecurityError if check fails
    private func checkSecurityScopedAccess(to url: URL) async throws -> Bool {
        // Find bookmark
        guard let bookmark = try? await bookmarkService.findBookmark(for: url) else {
            return false
        }
        
        // Resolve bookmark
        var isStale = false
        _ = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        return !isStale
    }
    
    /// Validates access to the sandbox container.
    ///
    /// - Returns: True if sandbox access is valid
    /// - Throws: SecurityError if validation fails
    private func validateSandboxAccess() async throws -> Bool {
        // Get sandbox container
        guard let container = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return false
        }
        
        // Check container access
        return FileManager.default.isWritableFile(atPath: container.path)
    }
    
    /// Validates access to a directory.
    ///
    /// - Parameter url: The URL of the directory to validate
    /// - Returns: True if directory access is valid
    /// - Throws: SecurityError if validation fails
    private func validateDirectoryAccess(at url: URL) throws -> Bool {
        // Check directory permissions
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isReadableKey, .isWritableKey],
            options: .skipsHiddenFiles
        )
        
        // Check read/write access
        for item in contents {
            var isReadable: AnyObject?
            var isWritable: AnyObject?
            
            try item.getResourceValue(&isReadable, forKey: .isReadableKey)
            try item.getResourceValue(&isWritable, forKey: .isWritableKey)
            
            guard let readable = isReadable as? Bool,
                  let writable = isWritable as? Bool,
                  readable && writable else {
                return false
            }
        }
        
        return true
    }
}
