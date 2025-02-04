import Foundation
import Core

/// Service for persisting and managing security-scoped bookmarks
public final class BookmarkPersistenceService: BaseSandboxedService, BookmarkPersistenceProtocol, HealthCheckable {
    // MARK: - Properties
    private let keychainService: KeychainServiceProtocol
    private let operationQueue: OperationQueue
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.bookmarkPersistence", attributes: .concurrent)
    private var activeOperations: Set<UUID> = []
    private var activeBookmarks: Set<URL> = []
    
    public var isHealthy: Bool {
        // Check if we have any stuck operations or leaked bookmarks
        accessQueue.sync {
            activeOperations.isEmpty && activeBookmarks.isEmpty
        }
    }
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        keychainService: KeychainServiceProtocol
    ) {
        self.keychainService = keychainService
        
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "dev.mpy.rBUM.bookmarkPersistenceQueue"
        self.operationQueue.maxConcurrentOperationCount = 1
        
        super.init(logger: logger, securityService: securityService)
    }
    
    // MARK: - BookmarkPersistenceProtocol Implementation
    public func createBookmark(for url: URL, readOnly: Bool = false) async throws -> Data {
        let operationId = UUID()
        
        return try await measure("Create Bookmark") {
            // Track operation
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            do {
                var options: URL.BookmarkCreationOptions = [.withSecurityScope]
                if readOnly {
                    options.insert(.securityScopeAllowOnlyReadAccess)
                }
                
                // Create bookmark
                let bookmark = try url.bookmarkData(
                    options: options,
                    includingResourceValuesForKeys: [
                        .isDirectoryKey,
                        .volumeURLKey,
                        .volumeNameKey
                    ],
                    relativeTo: nil
                )
                
                // Store in keychain
                try keychainService.storeBookmark(bookmark, for: url)
                
                logger.info("Created bookmark for \(url.path)")
                return bookmark
            } catch {
                logger.error("Failed to create bookmark: \(error.localizedDescription)")
                throw BookmarkError.creationFailed(error.localizedDescription)
            }
        }
    }
    
    public func resolveBookmark(_ bookmark: Data) async throws -> URL {
        let operationId = UUID()
        
        return try await measure("Resolve Bookmark") {
            // Track operation
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    logger.warning("Bookmark is stale for \(url.path)")
                    throw BookmarkError.staleBookmark
                }
                
                logger.info("Resolved bookmark for \(url.path)")
                return url
            } catch let error as BookmarkError {
                throw error
            } catch {
                logger.error("Failed to resolve bookmark: \(error.localizedDescription)")
                throw BookmarkError.resolutionFailed(error.localizedDescription)
            }
        }
    }
    
    public func startAccessing(_ url: URL) async throws -> Bool {
        let operationId = UUID()
        
        return try await measure("Start Accessing Resource") {
            // Track operation
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            do {
                // Get bookmark from keychain
                let bookmark = try keychainService.retrieveBookmark(for: url)
                
                // Resolve bookmark
                let resolvedUrl = try await resolveBookmark(bookmark)
                
                // Start accessing
                guard resolvedUrl.startAccessingSecurityScopedResource() else {
                    logger.warning("Failed to start accessing \(url.path)")
                    return false
                }
                
                // Track active bookmark
                accessQueue.async(flags: .barrier) {
                    self.activeBookmarks.insert(url)
                }
                
                logger.info("Started accessing \(url.path)")
                return true
            } catch {
                logger.error("Failed to start accessing: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    public func stopAccessing(_ url: URL) {
        let operationId = UUID()
        
        measure("Stop Accessing Resource") {
            // Track operation
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            url.stopAccessingSecurityScopedResource()
            
            // Remove from active bookmarks
            accessQueue.async(flags: .barrier) {
                self.activeBookmarks.remove(url)
            }
            
            logger.info("Stopped accessing \(url.path)")
        }
    }
    
    public func validateBookmark(for url: URL) async throws -> Bool {
        try await measure("Validate Bookmark") {
            do {
                // Check if bookmark exists in keychain
                let bookmark = try keychainService.retrieveBookmark(for: url)
                
                // Try to resolve it
                _ = try await resolveBookmark(bookmark)
                
                logger.info("Successfully validated bookmark for \(url.path)")
                return true
            } catch {
                logger.warning("Failed to validate bookmark: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Bookmark Persistence Service Health Check") {
            do {
                // Check dependencies
                guard await keychainService.performHealthCheck() else {
                    return false
                }
                
                // Check for stuck operations
                let stuckOperations = accessQueue.sync { activeOperations }
                if !stuckOperations.isEmpty {
                    logger.warning("Found \(stuckOperations.count) potentially stuck operations")
                    return false
                }
                
                // Check for leaked bookmarks
                let leakedBookmarks = accessQueue.sync { activeBookmarks }
                if !leakedBookmarks.isEmpty {
                    logger.warning("Found \(leakedBookmarks.count) potentially leaked bookmarks")
                    return false
                }
                
                logger.info("Bookmark persistence service health check passed")
                return true
            } catch {
                logger.error("Bookmark persistence service health check failed: \(error.localizedDescription)")
                return false
            }
        }
    }
}

// MARK: - Bookmark Errors
public enum BookmarkError: LocalizedError {
    case creationFailed(String)
    case resolutionFailed(String)
    case staleBookmark
    case accessDenied
    case invalidBookmark
    
    public var errorDescription: String? {
        switch self {
        case .creationFailed(let message):
            return "Failed to create bookmark: \(message)"
        case .resolutionFailed(let message):
            return "Failed to resolve bookmark: \(message)"
        case .staleBookmark:
            return "Bookmark is stale and needs to be recreated"
        case .accessDenied:
            return "Access denied to bookmarked resource"
        case .invalidBookmark:
            return "Invalid or corrupted bookmark"
        }
    }
}
