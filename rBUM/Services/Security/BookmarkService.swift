import Core
import Foundation

/// Service for managing security-scoped bookmarks
public final class BookmarkService: BaseSandboxedService, BookmarkServiceProtocol, HealthCheckable {
    // MARK: - Properties

    let keychainService: KeychainServiceProtocol
    let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.bookmarkService", attributes: .concurrent)
    var activeBookmarks: [URL: BookmarkAccess] = [:]

    public var isHealthy: Bool {
        // Check if any bookmarks have been accessed for too long
        accessQueue.sync {
            !activeBookmarks.values.contains { $0.hasExceededMaxDuration }
        }
    }

    // MARK: - Types

    struct BookmarkAccess {
        let startTime: Date
        let maxDuration: TimeInterval
        let bookmark: Data

        var hasExceededMaxDuration: Bool {
            Date().timeIntervalSince(startTime) > maxDuration
        }
    }

    // MARK: - Initialization

    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        keychainService: KeychainServiceProtocol
    ) {
        self.keychainService = keychainService
        super.init(logger: logger, securityService: securityService)
    }

    // MARK: - HealthCheckable Implementation

    public func performHealthCheck() async -> Bool {
        await measure("Bookmark Service Health Check") {
            do {
                // Check keychain service health
                guard await keychainService.performHealthCheck() else {
                    return false
                }

                // Check for stuck bookmarks
                let stuckBookmarks = accessQueue.sync {
                    activeBookmarks.filter(\.value.hasExceededMaxDuration)
                }

                if !stuckBookmarks.isEmpty {
                    logger.warning("Found \(stuckBookmarks.count) stuck bookmarks")
                    // Clean up stuck bookmarks
                    for (url, _) in stuckBookmarks {
                        stopAccessing(url)
                    }
                    return false
                }

                logger.info("Bookmark service health check passed")
                return true
            } catch {
                logger.error("Bookmark service health check failed: \(error.localizedDescription)")
                return false
            }
        }
    }
}

// MARK: - Bookmark Errors

public enum BookmarkError: LocalizedError {
    case creationFailed(String)
    case resolutionFailed(String)
    case accessDenied
    case invalidBookmark
    case bookmarkExpired

    public var errorDescription: String? {
        switch self {
        case let .creationFailed(message):
            "Failed to create bookmark: \(message)"
        case let .resolutionFailed(message):
            "Failed to resolve bookmark: \(message)"
        case .accessDenied:
            "Access denied to security-scoped resource"
        case .invalidBookmark:
            "Invalid bookmark data"
        case .bookmarkExpired:
            "Bookmark has expired"
        }
    }
}
