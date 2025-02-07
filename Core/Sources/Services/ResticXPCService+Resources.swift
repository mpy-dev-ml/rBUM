import Foundation
import os.log

// MARK: - Resource Management

@available(macOS 13.0, *)
extension ResticXPCService {
    /// Start accessing security-scoped resources using the provided bookmarks
    /// - Parameter bookmarks: Dictionary mapping paths to their security-scoped bookmarks
    /// - Throws: ResticXPCError if bookmark resolution or access fails
    func startAccessingResources(_ bookmarks: [String: NSData]) throws {
        for (path, bookmark) in bookmarks {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark as Data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                throw ResticXPCError.invalidBookmark(path: path)
            }

            if isStale {
                throw ResticXPCError.staleBookmark(path: path)
            }

            guard url.startAccessingSecurityScopedResource() else {
                throw ResticXPCError.accessDenied(path: path)
            }

            activeBookmarks[path] = bookmark
        }
    }

    /// Stop accessing all active security-scoped resources and clean up bookmarks
    func stopAccessingResources() {
        for (path, bookmark) in activeBookmarks {
            if let url = try? URL(
                resolvingBookmarkData: bookmark as Data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: nil
            ) {
                url.stopAccessingSecurityScopedResource()
            }
            
            logger.debug(
                "Stopped accessing resource",
                metadata: ["path": .string(path)],
                file: #file,
                function: #function,
                line: #line
            )
        }
        
        activeBookmarks.removeAll()
    }
    
    /// Clean up all resources associated with the service
    func cleanupResources() {
        // Stop accessing security-scoped resources
        stopAccessingResources()
        
        // Cancel any pending operations
        pendingOperations.forEach { operation in
            operation.cancel()
        }
        pendingOperations.removeAll()
        
        // Invalidate connection
        connection?.invalidate()
        connection = nil
        
        logger.debug(
            "Cleaned up all resources",
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    /// Validates that all required resources are accessible
    /// - Throws: ResticXPCError if any required resource is inaccessible
    func validateResources() throws {
        // Check active bookmarks
        for (path, bookmark) in activeBookmarks {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark as Data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                throw ResticXPCError.invalidBookmark(path: path)
            }
            
            if isStale {
                throw ResticXPCError.staleBookmark(path: path)
            }
            
            guard url.startAccessingSecurityScopedResource() else {
                throw ResticXPCError.accessDenied(path: path)
            }
            
            url.stopAccessingSecurityScopedResource()
        }
        
        // Check connection
        guard connection != nil else {
            throw ResticXPCError.connectionNotEstablished
        }
        
        // Check pending operations
        for operation in pendingOperations where operation.isCancelled {
            pendingOperations.removeAll { $0 === operation }
        }
    }
}
