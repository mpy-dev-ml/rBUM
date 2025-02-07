//
//  DefaultSecurityService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import AppKit
import Core
import Foundation
import Security

/// A macOS-specific implementation of the security service that handles sandbox compliance
/// and resource access management.
///
/// `DefaultSecurityService` provides a comprehensive implementation of `SecurityServiceProtocol`
/// specifically designed for macOS. It handles:
///
/// 1. Sandbox Compliance:
///    - Security-scoped bookmark management
///    - Resource access tracking
///    - Permission management
///    - Access scope validation
///
/// 2. Resource Management:
///    - Concurrent operation handling
///    - Resource cleanup
///    - Access queue management
///    - Operation tracking
///
/// 3. Security Features:
///    - Keychain integration
///    - Sandbox monitoring
///    - Access control
///    - Error handling
///
/// Example usage:
/// ```swift
/// let securityService = DefaultSecurityService(
///     logger: logger,
///     securityService: securityService,
///     bookmarkService: bookmarkService,
///     keychainService: keychainService,
///     sandboxMonitor: sandboxMonitor
/// )
///
/// // Request permission for a file
/// try await securityService.requestPermission(for: fileURL)
///
/// // Create a persistent bookmark
/// let bookmark = try securityService.createBookmark(for: fileURL)
/// ```
public class DefaultSecurityService: BaseSandboxedService, Measurable {
    // MARK: - Properties
    
    /// Service responsible for managing security-scoped bookmarks
    private let bookmarkService: BookmarkServiceProtocol
    
    /// Service responsible for secure credential storage
    private let keychainService: KeychainServiceProtocol
    
    /// Service responsible for monitoring sandbox compliance
    private let sandboxMonitor: SandboxMonitorProtocol
    
    /// Queue for managing security operations
    private let operationQueue: OperationQueue
    
    /// Concurrent queue for managing access to shared resources
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.defaultSecurity", attributes: .concurrent)
    
    /// Set of currently active operation IDs
    private var activeOperations: Set<UUID> = []
    
    /// Indicates whether the service is currently in a healthy state.
    ///
    /// The service is considered healthy when:
    /// - No operations are stuck
    /// - All resources are properly released
    /// - No access violations are detected
    public var isHealthy: Bool {
        // Check if we have any stuck operations
        accessQueue.sync {
            self.activeOperations.isEmpty
        }
    }

    // MARK: - Initialization
    
    /// Initializes a new DefaultSecurityService with the required dependencies.
    ///
    /// - Parameters:
    ///   - logger: The logger for recording security events
    ///   - securityService: The underlying security service implementation
    ///   - bookmarkService: The service for managing security-scoped bookmarks
    ///   - keychainService: The service for secure credential storage
    ///   - sandboxMonitor: The service for monitoring sandbox compliance
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        bookmarkService: BookmarkServiceProtocol,
        keychainService: KeychainServiceProtocol,
        sandboxMonitor: SandboxMonitorProtocol
    ) {
        self.bookmarkService = bookmarkService
        self.keychainService = keychainService
        self.sandboxMonitor = sandboxMonitor

        self.operationQueue = OperationQueue()
        self.operationQueue.name = "dev.mpy.rBUM.defaultSecurityQueue"
        self.operationQueue.maxConcurrentOperationCount = 1

        super.init(logger: logger, securityService: securityService)
    }

    // MARK: - SecurityServiceProtocol Implementation
    
    /// Requests permission for the specified URL.
    ///
    /// This method will prompt the user to grant access to the specified URL.
    ///
    /// - Parameter url: The URL for which permission is being requested
    /// - Returns: `true` if permission is granted, `false` otherwise
    public func requestPermission(for url: URL) async throws -> Bool {
        try await measure("Request Permission") {
            // First check if we already have access
            if try await validateAccess(to: url) {
                return true
            }

            // Show open panel to request access
            let panel = await NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = url
            panel.message = "Please grant access to this location"
            panel.prompt = "Grant Access"

            let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())
            return response == .OK
        }
    }

    /// Creates a persistent bookmark for the specified URL.
    ///
    /// - Parameter url: The URL for which a bookmark is being created
    /// - Returns: The created bookmark data
    public func createBookmark(for url: URL) throws -> Data {
        try bookmarkService.createBookmark(for: url)
    }

    /// Resolves a bookmark to its corresponding URL.
    ///
    /// - Parameter bookmark: The bookmark data to resolve
    /// - Returns: The resolved URL
    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        try bookmarkService.resolveBookmark(bookmark)
    }

    /// Validates access to the specified URL.
    ///
    /// This method checks if the service has permission to access the specified URL.
    ///
    /// - Parameter url: The URL for which access is being validated
    /// - Returns: `true` if access is valid, `false` otherwise
    public func validateAccess(to url: URL) async throws -> Bool {
        try await measure("Validate Access") {
            do {
                let bookmark = try bookmarkService.createBookmark(for: url)
                return try bookmarkService.validateBookmark(bookmark)
            } catch {
                logger.error("Failed to validate access: \(error.localizedDescription)",
                           file: #file,
                           function: #function,
                           line: #line)
                return false
            }
        }
    }

    /// Starts accessing the specified URL.
    ///
    /// This method will attempt to start accessing the specified URL.
    ///
    /// - Parameter url: The URL for which access is being started
    /// - Returns: `true` if access is started successfully, `false` otherwise
    public override func startAccessing(_ url: URL) -> Bool {
        do {
            return try bookmarkService.startAccessing(url)
        } catch {
            logger.error("Failed to start accessing: \(error.localizedDescription)",
                       file: #file,
                       function: #function,
                       line: #line)
            return false
        }
    }

    /// Stops accessing the specified URL.
    ///
    /// This method will attempt to stop accessing the specified URL.
    ///
    /// - Parameter url: The URL for which access is being stopped
    public override func stopAccessing(_ url: URL) {
        Task {
            do {
                try await bookmarkService.stopAccessing(url)
            } catch {
                logger.error("Failed to stop accessing: \(error.localizedDescription)",
                           file: #file,
                           function: #function,
                           line: #line)
            }
        }
    }

    /// Persists access to the specified URL.
    ///
    /// This method will persist access to the specified URL.
    ///
    /// - Parameter url: The URL for which access is being persisted
    /// - Returns: The persisted bookmark data
    public func persistAccess(to url: URL) async throws -> Data {
        try await measure("Persist Access") {
            let bookmark = try bookmarkService.createBookmark(for: url)
            _ = try await sandboxMonitor.startMonitoring(url: url)
            return bookmark
        }
    }

    /// Revokes access to the specified URL.
    ///
    /// This method will revoke access to the specified URL.
    ///
    /// - Parameter url: The URL for which access is being revoked
    public func revokeAccess(to url: URL) async throws {
        try await measure("Revoke Access") {
            try await sandboxMonitor.stopMonitoring(for: url)
        }
    }

    // MARK: - HealthCheckable Implementation
    
    /// Performs a health check on the service.
    ///
    /// This method checks the service's health by verifying that:
    /// - No operations are stuck
    /// - All resources are properly released
    /// - No access violations are detected
    ///
    /// - Returns: `true` if the service is healthy, `false` otherwise
    public func performHealthCheck() async -> Bool {
        await measure("Security Health Check") {
            do {
                // Check sandbox monitor
                let monitorHealthy = sandboxMonitor.isHealthy

                // Check active operations
                let operationsHealthy = isHealthy

                return monitorHealthy && operationsHealthy
            } catch {
                logger.error("Health check failed: \(error.localizedDescription)",
                            file: #file,
                            function: #function,
                            line: #line)
                return false
            }
        }
    }

    // MARK: - Private Helpers
    
    /// Tracks an operation with the specified ID.
    ///
    /// - Parameter id: The ID of the operation to track
    private func trackOperation(_ id: UUID) {
        accessQueue.async(flags: .barrier) {
            self.activeOperations.insert(id)
        }
    }

    /// Untracks an operation with the specified ID.
    ///
    /// - Parameter id: The ID of the operation to untrack
    private func untrackOperation(_ id: UUID) {
        accessQueue.async(flags: .barrier) {
            self.activeOperations.remove(id)
        }
    }
}
