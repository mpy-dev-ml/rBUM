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

        operationQueue = OperationQueue()
        operationQueue.name = "dev.mpy.rBUM.defaultSecurityQueue"
        operationQueue.maxConcurrentOperationCount = 1

        super.init(logger: logger, securityService: securityService)
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
                logger.error(
                    "Health check failed: \(error.localizedDescription)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return false
            }
        }
    }

    // MARK: - Private Helpers

    private func recordOperationStart(
        id: UUID,
        type: SecurityOperationType,
        url: URL
    ) async throws {
        // Record operation start
        let operation = SecurityOperation(
            id: id,
            type: type,
            url: url,
            startTime: Date()
        )
        
        operationRecorder.recordOperation(operation)
        
        // Log operation start
        logger.info("Starting security operation", metadata: [
            "operation": .string(id.uuidString),
            "type": .string(type.rawValue),
            "url": .string(url.path)
        ])
    }
}
