//
//  DevelopmentSecurityService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 7 February 2025
//

import Foundation
import os.log

/// Configuration for controlling the development security service's behaviour
@objc public class DevelopmentConfiguration: NSObject {
    /// Whether to simulate permission request failures
    @objc public let shouldSimulatePermissionFailures: Bool
    
    /// Whether to simulate bookmark failures
    @objc public let shouldSimulateBookmarkFailures: Bool
    
    /// Whether to simulate access failures
    @objc public let shouldSimulateAccessFailures: Bool
    
    /// Artificial delay to add to operations (in seconds)
    @objc public let artificialDelay: TimeInterval
    
    /// Initialize a new development configuration
    /// - Parameters:
    ///   - shouldSimulatePermissionFailures: Whether to simulate permission failures
    ///   - shouldSimulateBookmarkFailures: Whether to simulate bookmark failures
    ///   - shouldSimulateAccessFailures: Whether to simulate access failures
    ///   - artificialDelay: Artificial delay to add to operations
    @objc public init(
        shouldSimulatePermissionFailures: Bool = false,
        shouldSimulateBookmarkFailures: Bool = false,
        shouldSimulateAccessFailures: Bool = false,
        artificialDelay: TimeInterval = 0.0
    ) {
        self.shouldSimulatePermissionFailures = shouldSimulatePermissionFailures
        self.shouldSimulateBookmarkFailures = shouldSimulateBookmarkFailures
        self.shouldSimulateAccessFailures = shouldSimulateAccessFailures
        self.artificialDelay = artificialDelay
        super.init()
    }
    
    /// Default configuration for development environment
    ///
    /// Returns a `DevelopmentConfiguration` instance with default settings for
    /// simulating security operations in a development environment.
    @objc public static var `default`: DevelopmentConfiguration {
        return DevelopmentConfiguration()
    }
}

/// Development implementation of SecurityServiceProtocol for testing and development
@available(macOS 13.0, *)
@objc public final class DevelopmentSecurityService: NSObject, SecurityServiceProtocol {
    // MARK: - Properties

    /// Logger instance for recording security-related events
    internal let logger: LoggerProtocol
    
    /// Configuration for controlling development behavior
    private let configuration: DevelopmentConfiguration
    
    /// Serial queue for synchronising access to shared resources
    internal let queue = DispatchQueue(label: "dev.mpy.rbum.security")

    /// Dictionary mapping URLs to their security-scoped bookmark data
    internal var bookmarks: [URL: Data] = [:]

    /// Metrics collector for tracking security operations
    internal let metrics: SecurityMetrics

    /// Recorder for logging security operations
    internal let operationRecorder: SecurityOperationRecorder

    /// Simulator for controlling operation behaviour
    internal let simulator: SecuritySimulator

    /// File manager for file system operations
    internal let fileManager: FileManager
    
    /// Bookmark service for managing security-scoped bookmarks
    internal let bookmarkService: BookmarkServiceProtocol
    
    /// Keychain service for secure storage
    internal let keychainService: KeychainServiceProtocol

    // MARK: - Initialization

    /// Creates a new development security service
    /// - Parameters:
    ///   - logger: Logger for recording events
    ///   - bookmarkService: Service for managing security-scoped bookmarks
    ///   - keychainService: Service for secure storage
    ///   - configuration: Optional configuration controlling behaviour
    @objc public init(
        logger: LoggerProtocol,
        bookmarkService: BookmarkServiceProtocol,
        keychainService: KeychainServiceProtocol,
        configuration: DevelopmentConfiguration = .default
    ) {
        self.logger = logger
        self.bookmarkService = bookmarkService
        self.keychainService = keychainService
        self.configuration = configuration
        self.fileManager = FileManager.default
        
        // Initialize development tools
        self.metrics = SecurityMetrics(logger: logger as! Logger)
        self.operationRecorder = SecurityOperationRecorder(logger: logger as! Logger)
        self.simulator = SecuritySimulator(
            logger: logger as! Logger,
            configuration: configuration
        )
        super.init()
    }
    
    // MARK: - SecurityServiceProtocol
    
    /// Requests permission for accessing a URL
    ///
    /// Simulates a permission request and returns the result.
    /// - Parameters:
    ///   - url: URL for which permission is requested
    /// - Returns: Whether permission was granted
    /// - Throws: `SecurityError` if permission is denied
    @objc public func requestPermission(for url: URL) async throws -> Bool {
        try await simulator.simulateDelay()
        
        if configuration.shouldSimulateAccessFailures {
            throw SecurityError.permissionDenied("Permission denied (simulated)")
        }
        
        operationRecorder.recordOperation(
            url: url,
            type: SecurityOperationType.permission,
            status: SecurityOperationStatus.success
        )
        
        return true
    }
    
    /// Creates a security-scoped bookmark for a URL
    ///
    /// Simulates bookmark creation and returns the bookmark data.
    /// - Parameters:
    ///   - url: URL for which a bookmark is created
    /// - Returns: Bookmark data
    /// - Throws: `SecurityError` if bookmark creation fails
    @objc public func createBookmark(for url: URL) throws -> Data {
        try simulator.simulateDelay()
        
        if configuration.shouldSimulateBookmarkFailures {
            throw SecurityError.bookmarkCreationFailed("Bookmark creation failed (simulated)")
        }
        
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        bookmarks[url] = bookmark
        
        operationRecorder.recordOperation(
            url: url,
            type: SecurityOperationType.bookmark,
            status: SecurityOperationStatus.success
        )
        
        return bookmark
    }
    
    /// Validates a security-scoped bookmark for a URL
    ///
    /// Simulates bookmark validation and returns the result.
    /// - Parameters:
    ///   - bookmark: Bookmark data to validate
    ///   - url: URL for which the bookmark is validated
    /// - Returns: Whether the bookmark is valid
    /// - Throws: `SecurityError` if bookmark validation fails
    @objc public func validateBookmark(_ bookmark: Data, for url: URL) throws -> Bool {
        try simulator.simulateDelay()
        
        if configuration.shouldSimulateBookmarkFailures {
            throw SecurityError.bookmarkInvalid("Bookmark validation failed (simulated)")
        }
        
        let isValid = bookmarks[url] == bookmark
        
        operationRecorder.recordOperation(
            url: url,
            type: SecurityOperationType.bookmark,
            status: isValid ? SecurityOperationStatus.success : SecurityOperationStatus.failure,
            error: isValid ? nil : "Bookmark mismatch"
        )
        
        return isValid
    }
    
    /// Starts accessing a URL
    ///
    /// Simulates starting access to a URL.
    /// - Parameters:
    ///   - url: URL for which access is started
    /// - Throws: `SecurityError` if access is denied
    @objc public func startAccessing(_ url: URL) throws {
        try simulator.simulateDelay()
        
        if configuration.shouldSimulateAccessFailures {
            throw SecurityError.accessDenied("Access denied (simulated)")
        }
        
        operationRecorder.recordOperation(
            url: url,
            type: SecurityOperationType.access,
            status: SecurityOperationStatus.success
        )
    }
    
    /// Stops accessing a URL
    ///
    /// Simulates stopping access to a URL.
    /// - Parameters:
    ///   - url: URL for which access is stopped
    @objc public func stopAccessing(_ url: URL) {
        operationRecorder.recordOperation(
            url: url,
            type: SecurityOperationType.access,
            status: SecurityOperationStatus.success
        )
    }
}
