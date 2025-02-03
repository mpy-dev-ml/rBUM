import Foundation

/// Service implementing security operations with sandbox compliance and XPC support
public final class SecurityService {
    private let logger: LoggerProtocol
    private let xpcService: ResticXPCServiceProtocol
    private var activeBookmarks: [URL: Data] = [:]
    private let bookmarkQueue = DispatchQueue(label: "dev.mpy.rBUM.SecurityService.bookmarks")
    
    /// Initialize the security service
    /// - Parameters:
    ///   - logger: Logger for tracking operations
    ///   - xpcService: XPC service for command execution
    public init(
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "SecurityService") as! LoggerProtocol,
        xpcService: ResticXPCServiceProtocol
    ) {
        self.logger = logger
        self.xpcService = xpcService
    }
    
    /// Safely access active bookmarks
    private func getActiveBookmark(for url: URL) -> Data? {
        bookmarkQueue.sync { activeBookmarks[url] }
    }
    
    /// Safely store active bookmark
    private func setActiveBookmark(_ bookmark: Data, for url: URL) {
        bookmarkQueue.sync { activeBookmarks[url] = bookmark }
    }
    
    /// Safely remove active bookmark
    private func removeActiveBookmark(for url: URL) {
        bookmarkQueue.sync { activeBookmarks.removeValue(forKey: url) }
    }
    
    /// Handle bookmark creation with proper error handling
    private func createSecurityScopedBookmark(for url: URL) throws -> Data {
        logger.debug("Creating security-scoped bookmark for: \(url.path)", file: #file, function: #function, line: #line)
        
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            logger.info("Successfully created bookmark for: \(url.path)", file: #file, function: #function, line: #line)
            return bookmark
        } catch {
            logger.error("Failed to create bookmark: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw SecurityError.bookmarkCreationFailed("Failed to create bookmark: \(error.localizedDescription)")
        }
    }
    
    /// Handle bookmark resolution with proper error handling
    private func resolveSecurityScopedBookmark(_ bookmark: Data) throws -> URL {
        logger.debug("Resolving security-scoped bookmark", file: #file, function: #function, line: #line)
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmark,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale)
            
            if isStale {
                logger.error("Bookmark is stale", file: #file, function: #function, line: #line)
                throw SecurityError.bookmarkStale("Bookmark is stale and needs to be recreated")
            }
            
            logger.info("Successfully resolved bookmark to: \(url.path)", file: #file, function: #function, line: #line)
            return url
        } catch {
            logger.error("Failed to resolve bookmark: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw SecurityError.bookmarkResolutionFailed("Failed to resolve bookmark: \(error.localizedDescription)")
        }
    }
}

// MARK: - SecurityServiceProtocol Implementation

extension SecurityService: SecurityServiceProtocol {
    public func validateXPCService() async throws -> Bool {
        logger.debug("Validating XPC service", file: #file, function: #function, line: #line)
        
        do {
            try await xpcService.connect()
            let isValid = try await xpcService.validatePermissions()
            if isValid {
                logger.info("XPC service validated successfully", file: #file, function: #function, line: #line)
            } else {
                logger.error("XPC service permissions invalid", file: #file, function: #function, line: #line)
            }
            return isValid
        } catch {
            logger.error("XPC service validation failed: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            return false
        }
    }
    
    public func requestPermission(for url: URL) async throws -> Bool {
        logger.debug("Requesting permission for: \(url.path)", file: #file, function: #function, line: #line)
        
        // Check if we already have an active bookmark
        if let existingBookmark = getActiveBookmark(for: url) {
            do {
                _ = try resolveSecurityScopedBookmark(existingBookmark)
                logger.info("Using existing permission for: \(url.path)", file: #file, function: #function, line: #line)
                return true
            } catch {
                // Existing bookmark is invalid, remove it
                removeActiveBookmark(for: url)
            }
        }
        
        // Create new bookmark
        do {
            let bookmark = try createSecurityScopedBookmark(for: url)
            setActiveBookmark(bookmark, for: url)
            logger.info("Permission granted for: \(url.path)", file: #file, function: #function, line: #line)
            return true
        } catch {
            logger.error("Permission denied for: \(url.path)", file: #file, function: #function, line: #line)
            return false
        }
    }
    
    public func createBookmark(for url: URL) async throws -> Data {
        logger.debug("Creating bookmark for: \(url.path)", file: #file, function: #function, line: #line)
        
        // Ensure we have permission
        guard try await requestPermission(for: url) else {
            throw SecurityError.permissionDenied("Permission not granted for URL")
        }
        
        // Create bookmark
        let bookmark = try createSecurityScopedBookmark(for: url)
        setActiveBookmark(bookmark, for: url)
        
        logger.info("Created and stored bookmark for: \(url.path)", file: #file, function: #function, line: #line)
        return bookmark
    }
    
    public func resolveBookmark(_ bookmark: Data) async throws -> URL {
        logger.debug("Resolving bookmark", file: #file, function: #function, line: #line)
        let url = try resolveSecurityScopedBookmark(bookmark)
        setActiveBookmark(bookmark, for: url)
        return url
    }
    
    public func startAccessing(_ url: URL) -> Bool {
        logger.debug("Starting access for: \(url.path)", file: #file, function: #function, line: #line)
        
        let success = url.startAccessingSecurityScopedResource()
        if success {
            logger.info("Started accessing: \(url.path)", file: #file, function: #function, line: #line)
        } else {
            logger.error("Failed to start accessing: \(url.path)", file: #file, function: #function, line: #line)
        }
        
        return success
    }
    
    public func stopAccessing(_ url: URL) {
        logger.debug("Stopping access for: \(url.path)", file: #file, function: #function, line: #line)
        url.stopAccessingSecurityScopedResource()
        logger.info("Stopped accessing: \(url.path)", file: #file, function: #function, line: #line)
    }
    
    public func prepareForXPCAccess(_ url: URL) async throws -> Data {
        logger.debug("Preparing XPC access for: \(url.path)", file: #file, function: #function, line: #line)
        
        // Ensure we have a valid bookmark
        let bookmark: Data
        if let existingBookmark = getActiveBookmark(for: url) {
            bookmark = existingBookmark
        } else {
            bookmark = try await createBookmark(for: url)
        }
        
        // Validate XPC service connection
        guard try await validateXPCService() else {
            throw SecurityError.xpcValidationFailed("XPC service validation failed")
        }
        
        logger.info("XPC access prepared for: \(url.path)", file: #file, function: #function, line: #line)
        return bookmark
    }
}
