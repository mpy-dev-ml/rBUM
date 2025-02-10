import AppKit
import Foundation

/// Service implementing security operations with sandbox compliance and XPC support
///
/// The SecurityService provides a comprehensive security layer for the application,
/// handling sandbox compliance, XPC communication, and security-scoped bookmarks.
/// It manages:
/// - Security-scoped bookmarks for file access
/// - User permission requests
/// - XPC service validation
/// - Access control for sandboxed resources
///
/// Example usage:
/// ```swift
/// let security = SecurityService(logger: logger, xpcService: xpc)
///
/// // Request permission
/// let granted = try await security.requestPermission(for: fileURL)
///
/// // Create and resolve bookmarks
/// let bookmark = try security.createBookmark(for: fileURL)
/// let url = try security.resolveBookmark(bookmark)
///
/// // Manage access
/// try security.startAccessing(url)
/// defer { try await security.stopAccessing(url) }
/// ```
///
/// Implementation notes:
/// 1. Thread-safe bookmark management
/// 2. Proper cleanup on application termination
/// 3. Comprehensive error handling
/// 4. Detailed logging
public final class SecurityService: SecurityServiceProtocol {
    // MARK: - Properties

    /// Logger for tracking operations
    let logger: LoggerProtocol

    /// XPC service for secure operations
    let xpcService: ResticXPCServiceProtocol

    /// Active bookmarks mapped by URL
    var activeBookmarks: [URL: Data] = [:]

    /// Queue for thread-safe bookmark operations
    let bookmarkQueue = DispatchQueue(label: "dev.mpy.rBUM.security.bookmarks", attributes: .concurrent)

    // MARK: - Initialization

    /// Initialize the security service
    /// - Parameters:
    ///   - logger: Logger for tracking operations
    ///   - xpcService: XPC service for secure operations
    public init(logger: LoggerProtocol, xpcService: ResticXPCServiceProtocol) {
        self.logger = logger
        self.xpcService = xpcService
        setupNotifications()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        logger.debug(
            "Setting up security notifications",
            file: #file,
            function: #function,
            line: #line
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func applicationWillTerminate(_: Notification) {
        bookmarkQueue.sync(flags: .barrier) {
            activeBookmarks.removeAll()
        }
    }
}
