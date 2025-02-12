import Foundation

/// A service that manages permission persistence and recovery for sandbox-compliant file access.
///
/// The `PermissionManager` provides a robust system for:
/// - Persisting security-scoped bookmarks
/// - Recovering file access permissions
/// - Sharing permissions with XPC services
/// - Managing permission lifecycle
///
/// ## Overview
///
/// Use `PermissionManager` to maintain persistent access to files and directories
/// selected by the user, even after app restart:
///
/// ```swift
/// let manager = PermissionManager(
///     logger: logger,
///     securityService: SecurityService(),
///     keychain: KeychainService()
/// )
///
/// // Store permission
/// try await manager.persistPermission(for: fileURL)
///
/// // Recover permission later
/// let hasAccess = try await manager.recoverPermission(for: fileURL)
/// ```
public class PermissionManager {
    // MARK: - Properties

    let logger: LoggerProtocol
    let securityService: SecurityServiceProtocol
    let keychain: KeychainServiceProtocol
    let fileManager: FileManager

    /// Prefix used for keychain permission entries to avoid naming conflicts
    let keychainPrefix = "dev.mpy.rBUM.permission."

    /// Access group identifier for sharing permissions with the XPC service
    let permissionAccessGroup = "dev.mpy.rBUM.permissions"

    // MARK: - Initialization

    /// Creates a new permission manager instance.
    ///
    /// - Parameters:
    ///   - logger: The logging service for debugging and diagnostics
    ///   - securityService: The service handling security-scoped bookmarks
    ///   - keychain: The service for securely storing permission data
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        keychain: KeychainServiceProtocol
    ) {
        self.logger = logger
        self.securityService = securityService
        self.keychain = keychain
        fileManager = FileManager.default

        do {
            try keychain.configureXPCSharing(accessGroup: permissionAccessGroup)
        } catch {
            self.logger.error(
                "Failed to configure XPC sharing: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    // MARK: - Public Methods

    /// Request and persist permission for a URL
    /// - Parameter url: The URL to request permission for
    /// - Returns: true if permission was granted and persisted
    public func requestAndPersistPermission(for url: URL) async throws -> Bool {
        logger.debug(
            "Requesting permission for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        do {
            // Request permission
            guard try await securityService.requestPermission(for: url) else {
                logger.error(
                    "Permission denied for: \(url.path)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return false
            }

            // Create and store bookmark
            let bookmark = try await securityService.createBookmark(for: url)
            try persistBookmark(bookmark, for: url)

            logger.info(
                "Permission granted and persisted for: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            return true

        } catch {
            logger.error(
                "Failed to request/persist permission: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw PermissionError.persistenceFailed(error.localizedDescription)
        }
    }

    /// Recover permission for a URL
    /// - Parameter url: The URL to recover permission for
    /// - Returns: true if permission was recovered
    public func recoverPermission(for url: URL) async throws -> Bool {
        logger.debug(
            "Attempting to recover permission for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        // Check for existing bookmark
        guard let bookmark = try loadBookmark(for: url) else {
            logger.debug(
                "No stored bookmark found for: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }

        // Attempt to resolve and verify bookmark
        guard let resolvedURL = try resolveAndVerifyBookmark(bookmark, originalURL: url) else {
            return false
        }

        // Test access
        guard try await testAccess(to: resolvedURL) else {
            try removeBookmark(for: url)
            return false
        }

        logger.info(
            "Successfully recovered permission for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }

    /// Check if permission exists for a URL
    /// - Parameter url: The URL to check
    /// - Returns: true if permission exists and is valid
    public func hasValidPermission(for url: URL) async throws -> Bool {
        do {
            guard let bookmark = try loadBookmark(for: url) else {
                return false
            }

            let resolvedURL = try securityService.resolveBookmark(bookmark)
            let canAccess = try await securityService.startAccessing(resolvedURL)
            if !canAccess {
                logger.error(
                    "Failed to access resolved URL: \(resolvedURL.path)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                try removeBookmark(for: url)
                return false
            }
            return resolvedURL.path == url.path

        } catch {
            logger.debug(
                "Permission check failed: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
    }

    /// Revoke permission for a URL
    /// - Parameter url: The URL to revoke permission for
    public func revokePermission(for url: URL) async throws {
        logger.debug(
            "Revoking permission for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        do {
            try removeBookmark(for: url)
            logger.info(
                "Permission revoked for: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )

        } catch {
            logger.error(
                "Failed to revoke permission: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw PermissionError.revocationFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private func persistBookmark(_ bookmark: Data, for url: URL) throws {
        logger.debug(
            "Persisting bookmark for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        do {
            try keychain.save(bookmark, for: url.path, accessGroup: permissionAccessGroup)
        } catch {
            logger.error(
                "Failed to persist bookmark: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw PermissionError.persistenceFailed(error.localizedDescription)
        }
    }

    private func loadBookmark(for url: URL) throws -> Data? {
        logger.debug(
            "Loading bookmark for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        return try keychain.retrieve(for: url.path, accessGroup: permissionAccessGroup)
    }

    private func removeBookmark(for url: URL) throws {
        logger.debug(
            "Removing bookmark for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        do {
            try keychain.delete(for: url.path, accessGroup: permissionAccessGroup)
        } catch {
            logger.error(
                "Failed to remove bookmark: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw PermissionError.revocationFailed(error.localizedDescription)
        }
    }

    /// Resolves and verifies a bookmark matches the original URL
    /// - Parameters:
    ///   - bookmark: The bookmark data to resolve
    ///   - originalURL: The original URL to verify against
    /// - Returns: The resolved URL if successful, nil otherwise
    private func resolveAndVerifyBookmark(_ bookmark: Data, originalURL: URL) throws -> URL? {
        // Attempt to resolve bookmark
        let resolvedURL = try securityService.resolveBookmark(bookmark)

        // Verify resolved URL matches original
        guard resolvedURL.path == originalURL.path else {
            logger.error(
                "Bookmark resolved to different path: \(resolvedURL.path)",
                file: #file,
                function: #function,
                line: #line
            )
            try removeBookmark(for: originalURL)
            return nil
        }

        return resolvedURL
    }

    /// Tests access to a URL using the security service
    /// - Parameter url: The URL to test access to
    /// - Returns: true if access was successful
    private func testAccess(to url: URL) async throws -> Bool {
        let canAccess = try await securityService.startAccessing(url)
        guard canAccess else {
            logger.error(
                "Failed to access resolved URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
        try await securityService.stopAccessing(url)
        return true
    }
}

/// Errors that can occur during permission operations
public enum PermissionError: LocalizedError {
    case persistenceFailed(String)
    case recoveryFailed(String)
    case revocationFailed(String)
    case fileNotFound(URL)
    case readAccessDenied(URL)
    case writeAccessDenied(URL)
    case fileEncrypted(URL)
    case sandboxAccessDenied(URL)
    case volumeReadOnly(URL)

    public var errorDescription: String? {
        switch self {
        case let .persistenceFailed(reason):
            "Failed to persist permission: \(reason)"
        case let .recoveryFailed(reason):
            "Failed to recover permission: \(reason)"
        case let .revocationFailed(reason):
            "Failed to revoke permission: \(reason)"
        case let .fileNotFound(url):
            "File not found: \(url.path)"
        case let .readAccessDenied(url):
            "Read access denied for file: \(url.path)"
        case let .writeAccessDenied(url):
            "Write access denied for file: \(url.path)"
        case let .fileEncrypted(url):
            "File is encrypted: \(url.path)"
        case let .sandboxAccessDenied(url):
            "Sandbox access denied for file: \(url.path)"
        case let .volumeReadOnly(url):
            "Volume is read-only for file: \(url.path)"
        }
    }
}
