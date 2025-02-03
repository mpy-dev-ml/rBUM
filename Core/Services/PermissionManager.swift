import Foundation

/// Manages permission persistence and recovery strategies for sandbox compliance
public class PermissionManager {
    private let logger: LoggerProtocol
    private let securityService: SecurityServiceProtocol
    private let keychain: KeychainServiceProtocol
    
    /// Prefix for keychain permission entries
    private let keychainPrefix = "dev.mpy.rBUM.permission."
    
    public init(
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "PermissionManager"),
        securityService: SecurityServiceProtocol = SecurityService(),
        keychain: KeychainServiceProtocol = KeychainService()
    ) {
        self.logger = logger
        self.securityService = securityService
        self.keychain = keychain
    }
    
    /// Request and persist permission for a URL
    /// - Parameter url: The URL to request permission for
    /// - Returns: true if permission was granted and persisted
    public func requestAndPersistPermission(for url: URL) async throws -> Bool {
        logger.debug("Requesting permission for: \(url.path, privacy: .private)")
        
        do {
            // Request permission
            guard try await securityService.requestPermission(for: url) else {
                logger.error("Permission denied for: \(url.path, privacy: .private)")
                return false
            }
            
            // Create and store bookmark
            let bookmark = try await securityService.createBookmark(for: url)
            try persistBookmark(bookmark, for: url)
            
            logger.info("Permission granted and persisted for: \(url.path, privacy: .private)")
            return true
            
        } catch {
            logger.error("Failed to request/persist permission: \(error.localizedDescription, privacy: .private)")
            throw PermissionError.persistenceFailed(error.localizedDescription)
        }
    }
    
    /// Recover permission for a URL
    /// - Parameter url: The URL to recover permission for
    /// - Returns: true if permission was recovered
    public func recoverPermission(for url: URL) async throws -> Bool {
        logger.debug("Attempting to recover permission for: \(url.path, privacy: .private)")
        
        do {
            // Check for existing bookmark
            guard let bookmark = try retrieveBookmark(for: url) else {
                logger.debug("No stored bookmark found for: \(url.path, privacy: .private)")
                return false
            }
            
            // Attempt to resolve bookmark
            let resolvedURL = try await securityService.resolveBookmark(bookmark)
            
            // Verify resolved URL matches original
            guard resolvedURL.path == url.path else {
                logger.error("Bookmark resolved to different path: \(resolvedURL.path, privacy: .private)")
                try removeBookmark(for: url)
                return false
            }
            
            // Test access
            guard securityService.startAccessing(resolvedURL) else {
                logger.error("Failed to access resolved URL: \(resolvedURL.path, privacy: .private)")
                try removeBookmark(for: url)
                return false
            }
            securityService.stopAccessing(resolvedURL)
            
            logger.info("Successfully recovered permission for: \(url.path, privacy: .private)")
            return true
            
        } catch {
            logger.error("Failed to recover permission: \(error.localizedDescription, privacy: .private)")
            
            // Clean up failed bookmark
            try? removeBookmark(for: url)
            
            throw PermissionError.recoveryFailed(error.localizedDescription)
        }
    }
    
    /// Check if permission exists for a URL
    /// - Parameter url: The URL to check
    /// - Returns: true if permission exists and is valid
    public func hasValidPermission(for url: URL) async throws -> Bool {
        do {
            guard let bookmark = try retrieveBookmark(for: url) else {
                return false
            }
            
            let resolvedURL = try await securityService.resolveBookmark(bookmark)
            return resolvedURL.path == url.path
            
        } catch {
            logger.debug("Permission check failed: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }
    
    /// Revoke permission for a URL
    /// - Parameter url: The URL to revoke permission for
    public func revokePermission(for url: URL) async throws {
        logger.debug("Revoking permission for: \(url.path, privacy: .private)")
        
        do {
            try removeBookmark(for: url)
            logger.info("Permission revoked for: \(url.path, privacy: .private)")
            
        } catch {
            logger.error("Failed to revoke permission: \(error.localizedDescription, privacy: .private)")
            throw PermissionError.revocationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    private func persistBookmark(_ bookmark: Data, for url: URL) throws {
        let key = keychainKey(for: url)
        try keychain.save(bookmark, for: key)
    }
    
    private func retrieveBookmark(for url: URL) throws -> Data? {
        let key = keychainKey(for: url)
        return try keychain.retrieve(for: key)
    }
    
    private func removeBookmark(for url: URL) throws {
        let key = keychainKey(for: url)
        try keychain.delete(for: key)
    }
    
    private func keychainKey(for url: URL) -> String {
        return keychainPrefix + url.path.replacingOccurrences(of: "/", with: "_")
    }
}

/// Errors that can occur during permission operations
public enum PermissionError: LocalizedError {
    case persistenceFailed(String)
    case recoveryFailed(String)
    case revocationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .persistenceFailed(let reason):
            return "Failed to persist permission: \(reason)"
        case .recoveryFailed(let reason):
            return "Failed to recover permission: \(reason)"
        case .revocationFailed(let reason):
            return "Failed to revoke permission: \(reason)"
        }
    }
}
