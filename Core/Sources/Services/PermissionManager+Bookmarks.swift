import Foundation

extension PermissionManager {
    // MARK: - Bookmark Management
    
    /// Manages security-scoped bookmarks for file system access
    func createBookmark(for url: URL) throws -> Data {
        guard url.startAccessingSecurityScopedResource() else {
            throw SecurityError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmarkData
        } catch {
            throw SecurityError.bookmarkCreationFailed(error)
        }
    }
    
    /// Resolves a security-scoped bookmark
    func resolveBookmark(_ bookmarkData: Data) throws -> URL {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                throw SecurityError.staleBookmark
            }
            
            return url
        } catch {
            if isStale {
                throw SecurityError.staleBookmark
            }
            throw SecurityError.bookmarkResolutionFailed(error)
        }
    }
    
    /// Validates if a bookmark is still valid and accessible
    func validateBookmark(_ bookmarkData: Data) -> Bool {
        do {
            let url = try resolveBookmark(bookmarkData)
            guard url.startAccessingSecurityScopedResource() else {
                return false
            }
            url.stopAccessingSecurityScopedResource()
            return true
        } catch {
            return false
        }
    }
    
    /// Starts accessing a security-scoped resource
    func startAccessing(_ url: URL) -> Bool {
        return url.startAccessingSecurityScopedResource()
    }
    
    /// Stops accessing a security-scoped resource
    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
