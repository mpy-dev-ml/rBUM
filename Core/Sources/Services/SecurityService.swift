import Foundation

/// Service implementing security operations with sandbox compliance and XPC support
public final class SecurityService: SecurityServiceProtocol {
    private let logger: LoggerProtocol
    private let xpcService: ResticXPCServiceProtocol
    private var activeBookmarks: [URL: Data] = [:]
    private let bookmarkQueue = DispatchQueue(label: "dev.mpy.rBUM.SecurityService.bookmarks")
    
    /// Initialize the security service
    /// - Parameters:
    ///   - logger: Logger for tracking operations
    ///   - xpcService: XPC service for command execution
    public init(
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "SecurityService"),
        xpcService: ResticXPCServiceProtocol
    ) {
        self.logger = logger
        self.xpcService = xpcService
        setupNotifications()
    }
    
    private func setupNotifications() {
        logger.debug("Setting up security notifications")
        
        let center = DistributedNotificationCenter.default()
        
        // Handle security preference changes
        center.addObserver(forName: .init("com.apple.security.plist.change"), object: nil, queue: nil) { [weak self] _ in
            guard let self = self else { return }
            
            // Sync changes to avoid race conditions
            self.bookmarkQueue.sync {
                _ = self.handleSecurityPreferenceChange()
            }
        }
        
        logger.debug("Security notifications setup complete")
    }
    
    private func handleSecurityPreferenceChange() -> Bool {
        // Handle security preference change logic here
        return true
    }
    
    /// Safely access active bookmarks
    private func getActiveBookmark(for url: URL) -> Data? {
        bookmarkQueue.sync { activeBookmarks[url] }
    }
    
    /// Safely store active bookmark
    private func setActiveBookmark(_ bookmark: Data, for url: URL) {
        bookmarkQueue.sync { activeBookmarks[url] = bookmark }
    }
    
    /// Remove active bookmark
    private func removeActiveBookmark(for url: URL) {
        bookmarkQueue.sync { activeBookmarks.removeValue(forKey: url) }
    }
    
    // MARK: - SecurityServiceProtocol
    
    public func validateAccess(to url: URL) async throws -> Bool {
        logger.debug("Validating access to: \(url.path)")
        
        // Check if we have an active bookmark
        if let bookmark = getActiveBookmark(for: url) {
            do {
                var isStale = false
                let resolvedURL = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if isStale {
                    logger.debug("Bookmark is stale for: \(url.path)")
                    removeActiveBookmark(for: url)
                    return false
                }
                
                if resolvedURL.startAccessingSecurityScopedResource() {
                    logger.debug("Successfully accessed: \(url.path)")
                    return true
                }
            } catch {
                logger.error("Failed to resolve bookmark: \(error.localizedDescription)")
                removeActiveBookmark(for: url)
            }
        }
        
        return false
    }
    
    public func stopAccessing(_ url: URL) async throws {
        logger.debug("Stopping access to: \(url.path)")
        url.stopAccessingSecurityScopedResource()
    }
    
    public func persistAccess(to url: URL) async throws -> Data {
        logger.debug("Persisting access to: \(url.path)")
        
        let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        setActiveBookmark(bookmark, for: url)
        return bookmark
    }
    
    public func validateXPCService() async throws -> Bool {
        logger.debug("Validating XPC service")
        
        do {
            return try await xpcService.validate()
        } catch {
            logger.error("XPC service validation failed: \(error.localizedDescription)")
            throw SecurityError.xpcServiceUnavailable
        }
    }
}
