//
//  DevelopmentSecurityService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation
import os.log

/// Development mock implementation of SecurityServiceProtocol
/// Provides controlled behaviour for development and testing
@available(macOS 13.0, *)
public final class DevelopmentSecurityService: SecurityServiceProtocol, @unchecked Sendable {
    // MARK: - Properties
    private let logger: Logger
    private let configuration: DevelopmentConfiguration
    private let queue = DispatchQueue(label: "dev.mpy.rbum.security")
    private var bookmarks: [URL: Data] = [:]
    
    private let metrics: SecurityMetrics
    private let operationRecorder: SecurityOperationRecorder
    private let simulator: SecuritySimulator
    
    // MARK: - Initialization
    public init(configuration: DevelopmentConfiguration) {
        self.configuration = configuration
        self.logger = Logger(subsystem: "dev.mpy.rbum", category: "SecurityService")
        self.metrics = SecurityMetrics(logger: logger)
        self.operationRecorder = SecurityOperationRecorder(logger: logger)
        self.simulator = SecuritySimulator(logger: logger, configuration: configuration)
    }
}

// MARK: - Access Control
@available(macOS 13.0, *)
extension DevelopmentSecurityService {
    /// Validates access to a URL
    /// - Parameter url: The URL to validate access for
    /// - Returns: True if access is valid, false otherwise
    /// - Throws: SecurityError if access validation fails
    public func validateAccess(to url: URL) async throws -> Bool {
        try simulator.simulateFailureIfNeeded(
            operation: "access validation",
            url: url,
            error: { SecurityError.accessDenied($0) }
        )
        
        try await simulator.simulateDelay()
        
        operationRecorder.recordOperation(
            url: url,
            type: .access,
            status: .success
        )
        metrics.recordAccess()
        
        logger.info(
            """
            Validating access to URL: \
            \(url.path)
            Active Access Count: \(metrics.activeAccessCount)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    /// Starts accessing a URL
    /// - Parameter url: The URL to start accessing
    /// - Returns: True if access was started successfully
    /// - Throws: SecurityError if access cannot be started
    public func startAccessing(_ url: URL) async throws -> Bool {
        try simulator.simulateFailureIfNeeded(
            operation: "access start",
            url: url,
            error: { SecurityError.accessDenied($0) }
        )
        
        try await simulator.simulateDelay()
        
        operationRecorder.recordOperation(
            url: url,
            type: .access,
            status: .success
        )
        metrics.recordAccess()
        metrics.incrementActiveAccess()
        
        logger.info(
            """
            Started accessing URL: \
            \(url.path)
            Active Access Count: \(metrics.activeAccessCount)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    /// Stops accessing a URL
    /// - Parameter url: The URL to stop accessing
    /// - Throws: SecurityError if access cannot be stopped
    public func stopAccessing(_ url: URL) async throws {
        try await simulator.simulateDelay()
        
        operationRecorder.recordOperation(
            url: url,
            type: .access,
            status: .success
        )
        metrics.recordAccessEnd()
        
        logger.info(
            """
            Stopped accessing URL: \
            \(url.path)
            Active Access Count: \(metrics.activeAccessCount)
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }
}

// MARK: - Bookmark Management
@available(macOS 13.0, *)
extension DevelopmentSecurityService {
    /// Persists access to a URL by creating a security-scoped bookmark
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: The bookmark data
    /// - Throws: SecurityError if bookmark creation fails
    public func persistAccess(to url: URL) async throws -> Data {
        try simulator.simulateFailureIfNeeded(
            operation: "bookmark creation",
            url: url,
            error: { SecurityError.bookmarkCreationFailed($0) }
        )
        
        try await simulator.simulateDelay()
        
        return try queue.sync {
            let string = "mock-bookmark-\(UUID().uuidString)"
            guard let bookmark = string.data(using: .utf8) else {
                let error = "Failed to create bookmark data"
                operationRecorder.recordOperation(
                    url: url,
                    type: .bookmark,
                    status: .failure,
                    error: error
                )
                metrics.recordBookmark(success: false, error: error)
                
                logger.error(
                    error,
                    file: #file,
                    function: #function,
                    line: #line
                )
                throw SecurityError.bookmarkCreationFailed(error)
            }
            
            bookmarks[url] = bookmark
            operationRecorder.recordOperation(
                url: url,
                type: .bookmark,
                status: .success
            )
            metrics.recordBookmark()
            
            logger.info(
                """
                Created bookmark for URL: \
                \(url.path)
                Total Bookmarks: \(bookmarks.count)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            return bookmark
        }
    }
    
    /// Resolves a security-scoped bookmark to its URL
    /// - Parameter bookmark: The bookmark data to resolve
    /// - Returns: The resolved URL
    /// - Throws: SecurityError if bookmark resolution fails
    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        try simulator.simulateFailureIfNeeded(
            operation: "bookmark resolution",
            url: URL(fileURLWithPath: "/"),
            error: { SecurityError.bookmarkResolutionFailed($0) }
        )
        
        return try queue.sync {
            if let url = bookmarks.first(where: { $0.value == bookmark })?.key {
                operationRecorder.recordOperation(
                    url: url,
                    type: .bookmark,
                    status: .success
                )
                metrics.recordBookmark()
                
                logger.info(
                    """
                    Resolved bookmark to URL: \
                    \(url.path)
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                return url
            }
            
            let error = "Bookmark not found"
            operationRecorder.recordOperation(
                url: URL(fileURLWithPath: "/"),
                type: .bookmark,
                status: .failure,
                error: error
            )
            metrics.recordBookmark(success: false, error: error)
            
            logger.error(
                error,
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.bookmarkResolutionFailed(error)
        }
    }
}

// MARK: - XPC Connection Management
@available(macOS 13.0, *)
extension DevelopmentSecurityService {
    /// Validates an XPC connection
    /// - Parameter connection: The XPC connection to validate
    /// - Returns: True if the connection is valid
    /// - Throws: SecurityError if validation fails
    public func validateXPCConnection(_ connection: NSXPCConnection) async throws -> Bool {
        try simulator.simulateFailureIfNeeded(
            operation: "XPC validation",
            url: URL(fileURLWithPath: "/"),
            error: { SecurityError.xpcConnectionFailed($0) }
        )
        
        try await simulator.simulateDelay()
        
        operationRecorder.recordOperation(
            url: URL(fileURLWithPath: "/"),
            type: .xpc,
            status: .success
        )
        
        logger.info(
            """
            Validated XPC connection: \
            \(connection)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    /// Validates the XPC service
    /// - Returns: True if the service is valid
    /// - Throws: SecurityError if validation fails
    public func validateXPCService() async throws -> Bool {
        try simulator.simulateFailureIfNeeded(
            operation: "XPC service validation",
            url: URL(fileURLWithPath: "/"),
            error: { SecurityError.xpcConnectionFailed($0) }
        )
        
        operationRecorder.recordOperation(
            url: URL(fileURLWithPath: "/"),
            type: .xpc,
            status: .success
        )
        
        logger.info(
            """
            Validated XPC service
            """,
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
}

// MARK: - Permission Management
@available(macOS 13.0, *)
extension DevelopmentSecurityService {
    /// Requests permission for a URL
    /// - Parameter url: The URL to request permission for
    /// - Returns: True if permission was granted
    /// - Throws: SecurityError if permission request fails
    public func requestPermission(for url: URL) async throws -> Bool {
        try simulator.simulateFailureIfNeeded(
            operation: "permission request",
            url: url,
            error: { SecurityError.accessDenied($0) }
        )
        
        try await simulator.simulateDelay()
        
        operationRecorder.recordOperation(
            url: url,
            type: .permission,
            status: .success
        )
        metrics.recordPermission()
        
        logger.info(
            """
            Requested permission for URL: \
            \(url.path)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    /// Validates access and starts accessing a URL in one operation
    /// - Parameter url: The URL to validate and access
    /// - Returns: True if validation and access were successful
    /// - Throws: SecurityError if validation or access fails
    public func validateAndStartAccessing(_ url: URL) async throws -> Bool {
        try simulator.simulateFailureIfNeeded(
            operation: "validate and access start",
            url: url,
            error: { SecurityError.accessDenied($0) }
        )
        
        try await simulator.simulateDelay()
        
        // First validate access
        _ = try await validateAccess(to: url)
        
        // Then start accessing
        return try await startAccessing(url)
    }
}
