import Core
import Foundation
import os.log

// MARK: - Security Operations

extension ResticService {
    /// Creates a new SecurityScopedAccess instance from bookmark data
    ///
    /// This method:
    /// 1. Resolves the bookmark data
    /// 2. Validates bookmark freshness
    /// 3. Creates a SecurityScopedAccess instance
    /// 4. Records the security operation
    ///
    /// - Parameter bookmarkData: The security-scoped bookmark data
    /// - Returns: A SecurityScopedAccess instance for the bookmarked resource
    /// - Throws: ResticXPCError if bookmark is invalid or stale
    func createSecurityScopedAccess(from bookmarkData: Data) throws -> SecurityScopedAccess {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                securityRecorder.recordOperation(
                    url: url,
                    type: .bookmark,
                    status: .failure,
                    error: "Stale bookmark"
                )
                throw ResticXPCError.bookmarkValidationFailed
            }
            
            let access = try SecurityScopedAccess(url: url)
            
            securityRecorder.recordOperation(
                url: url,
                type: .bookmark,
                status: .success
            )
            
            return access
        } catch {
            securityRecorder.recordOperation(
                url: URL(fileURLWithPath: "unknown"),
                type: .bookmark,
                status: .failure,
                error: error.localizedDescription
            )
            throw error
        }
    }
    
    /// Starts accessing a security-scoped resource
    ///
    /// This method:
    /// 1. Attempts to start accessing the resource
    /// 2. Records the security operation
    /// 3. Returns the success status
    ///
    /// - Parameter access: The SecurityScopedAccess to start
    /// - Returns: true if access was successfully started
    func startAccessing(_ access: SecurityScopedAccess) -> Bool {
        do {
            try access.startAccessing()
            
            securityRecorder.recordOperation(
                url: access.url,
                type: .access,
                status: .success
            )
            
            return true
        } catch {
            securityRecorder.recordOperation(
                url: access.url,
                type: .access,
                status: .failure,
                error: error.localizedDescription
            )
            return false
        }
    }
    
    /// Stops accessing a security-scoped resource
    ///
    /// This method:
    /// 1. Attempts to stop accessing the resource
    /// 2. Records the security operation
    /// 3. Handles any errors that occur
    ///
    /// - Parameter access: The SecurityScopedAccess to stop
    func stopAccessing(_ access: SecurityScopedAccess) {
        do {
            try access.stopAccessing()
            
            securityRecorder.recordOperation(
                url: access.url,
                type: .access,
                status: .success
            )
        } catch {
            securityRecorder.recordOperation(
                url: access.url,
                type: .access,
                status: .failure,
                error: error.localizedDescription
            )
        }
    }
}
