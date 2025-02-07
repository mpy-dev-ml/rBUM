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
    // MARK: - Types
    
    /// Represents a security operation with metadata
    private struct SecurityOperation: Hashable {
        let url: URL
        let operationType: OperationType
        let timestamp: Date
        let status: OperationStatus
        let error: String?
        
        enum OperationType: String {
            case access
            case permission
            case bookmark
            case xpc
        }
        
        enum OperationStatus: String {
            case success
            case failure
            case pending
        }
        
        static func == (lhs: SecurityOperation, rhs: SecurityOperation) -> Bool {
            return lhs.url == rhs.url &&
                   lhs.operationType == rhs.operationType &&
                   lhs.timestamp == rhs.timestamp
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(url)
            hasher.combine(operationType)
            hasher.combine(timestamp)
        }
    }
    
    /// Tracks security metrics
    private struct SecurityMetrics {
        private(set) var accessCount: Int = 0
        private(set) var permissionCount: Int = 0
        private(set) var bookmarkCount: Int = 0
        private(set) var xpcCount: Int = 0
        private(set) var failureCount: Int = 0
        private(set) var activeAccessCount: Int = 0
        private(set) var operationHistory: [SecurityOperation] = []
        
        mutating func recordAccess(success: Bool = true, error: String? = nil) {
            accessCount += 1
            if !success { failureCount += 1 }
        }
        
        mutating func recordPermission(success: Bool = true, error: String? = nil) {
            permissionCount += 1
            if !success { failureCount += 1 }
        }
        
        mutating func recordBookmark(success: Bool = true, error: String? = nil) {
            bookmarkCount += 1
            if !success { failureCount += 1 }
        }
        
        mutating func recordXPC(success: Bool = true, error: String? = nil) {
            xpcCount += 1
            if !success { failureCount += 1 }
        }
        
        mutating func recordOperation(
            _ operation: SecurityOperation
        ) {
            operationHistory.append(operation)
            if operationHistory.count > 100 {
                operationHistory.removeFirst()
            }
        }
        
        mutating func incrementActiveAccess() {
            activeAccessCount += 1
        }
        
        mutating func decrementActiveAccess() {
            activeAccessCount = max(0, activeAccessCount - 1)
        }
    }
    
    // MARK: - Properties
    private let logger: LoggerProtocol
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.developmentSecurity", attributes: .concurrent)
    private var bookmarks: [URL: Data] = [:]
    private var activeAccess: Set<URL> = []
    private let configuration: DevelopmentConfiguration
    private var metrics = SecurityMetrics()
    
    // MARK: - Initialization
    public init(logger: LoggerProtocol, configuration: DevelopmentConfiguration = .default) {
        self.logger = logger
        self.configuration = configuration
        
        logger.info(
            """
            Initialised DevelopmentSecurityService with configuration:
            \(String(describing: configuration))
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    // MARK: - Private Methods
    
    /// Record a security operation
    private func recordOperation(
        url: URL,
        type: SecurityOperation.OperationType,
        status: SecurityOperation.OperationStatus,
        error: String? = nil
    ) {
        queue.async(flags: .barrier) {
            let operation = SecurityOperation(
                url: url,
                operationType: type,
                timestamp: Date(),
                status: status,
                error: error
            )
            self.metrics.recordOperation(operation)
        }
    }
    
    /// Simulate failure if configured
    private func simulateFailureIfNeeded(
        operation: String,
        url: URL,
        error: (String) -> Error
    ) throws {
        guard configuration.shouldSimulateAccessFailures else { return }
        
        let errorMessage = "\(operation) failed (simulated)"
        logger.error(
            """
            Simulating \(operation) failure for URL: \
            \(url.path)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        throw error(errorMessage)
    }
    
    // MARK: - SecurityServiceProtocol Implementation
    public func validateAccess(to url: URL) async throws -> Bool {
        try simulateFailureIfNeeded(
            operation: "access validation",
            url: url,
            error: { SecurityError.accessDenied($0) }
        )
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        recordOperation(
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
    
    public func persistAccess(to url: URL) async throws -> Data {
        try simulateFailureIfNeeded(
            operation: "bookmark creation",
            url: url,
            error: { SecurityError.bookmarkCreationFailed($0) }
        )
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        return try queue.sync {
            let string = "mock-bookmark-\(UUID().uuidString)"
            guard let bookmark = string.data(using: .utf8) else {
                let error = "Failed to create bookmark data"
                recordOperation(
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
            recordOperation(
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
    
    public func validateXPCConnection(_ connection: NSXPCConnection) async throws -> Bool {
        try simulateFailureIfNeeded(
            operation: "XPC validation",
            url: URL(fileURLWithPath: "/"),
            error: { SecurityError.xpcConnectionFailed($0) }
        )
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        recordOperation(
            url: URL(fileURLWithPath: "/"),
            type: .xpc,
            status: .success
        )
        metrics.recordXPC()
        
        logger.info(
            """
            Validated XPC connection
            Total XPC Operations: \(metrics.xpcCount)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    public func validateXPCService() async throws -> Bool {
        try simulateFailureIfNeeded(
            operation: "XPC service validation",
            url: URL(fileURLWithPath: "/"),
            error: { SecurityError.xpcConnectionFailed($0) }
        )
        
        recordOperation(
            url: URL(fileURLWithPath: "/"),
            type: .xpc,
            status: .success
        )
        metrics.recordXPC()
        
        logger.info(
            """
            Validated XPC service
            Total XPC Operations: \(metrics.xpcCount)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    public func requestPermission(for url: URL) async throws -> Bool {
        try simulateFailureIfNeeded(
            operation: "permission request",
            url: url,
            error: { SecurityError.accessDenied($0) }
        )
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        recordOperation(
            url: url,
            type: .permission,
            status: .success
        )
        metrics.recordPermission()
        
        logger.info(
            """
            Granting permission for URL: \
            \(url.path)
            Total Permission Requests: \(metrics.permissionCount)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    public func createBookmark(for url: URL) throws -> Data {
        try simulateFailureIfNeeded(
            operation: "bookmark creation",
            url: url,
            error: { SecurityError.bookmarkCreationFailed($0) }
        )
        
        return try queue.sync {
            let string = "mock-bookmark-\(UUID().uuidString)"
            guard let bookmark = string.data(using: .utf8) else {
                let error = "Failed to create bookmark data"
                recordOperation(
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
            recordOperation(
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
    
    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        try simulateFailureIfNeeded(
            operation: "bookmark resolution",
            url: URL(fileURLWithPath: "/"),
            error: { SecurityError.bookmarkResolutionFailed($0) }
        )
        
        return try queue.sync {
            if let url = bookmarks.first(where: { $0.value == bookmark })?.key {
                recordOperation(
                    url: url,
                    type: .bookmark,
                    status: .success
                )
                metrics.recordBookmark()
                
                logger.info(
                    """
                    Resolved bookmark to URL: \
                    \(url.path)
                    Total Bookmarks: \(bookmarks.count)
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                return url
            }
            
            let error = "Bookmark not found"
            recordOperation(
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
    
    public func startAccessing(_ url: URL) async throws -> Bool {
        try simulateFailureIfNeeded(
            operation: "access start",
            url: url,
            error: { SecurityError.accessDenied($0) }
        )
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.activeAccess.insert(url)
                self.metrics.incrementActiveAccess()
                
                self.recordOperation(
                    url: url,
                    type: .access,
                    status: .success
                )
                self.metrics.recordAccess()
                
                self.logger.info(
                    """
                    Started accessing URL: \
                    \(url.path)
                    Active Access Count: \(self.metrics.activeAccessCount)
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                continuation.resume(returning: true)
            }
        }
    }
    
    public func stopAccessing(_ url: URL) async throws {
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.activeAccess.remove(url)
                self.metrics.decrementActiveAccess()
                
                self.recordOperation(
                    url: url,
                    type: .access,
                    status: .success
                )
                
                self.logger.info(
                    """
                    Stopped accessing URL: \
                    \(url.path)
                    Active Access Count: \(self.metrics.activeAccessCount)
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                continuation.resume()
            }
        }
    }
    
    public func validateAndStartAccessing(_ url: URL) async throws -> Bool {
        try simulateFailureIfNeeded(
            operation: "validate and access start",
            url: url,
            error: { SecurityError.accessDenied($0) }
        )
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        // First validate access
        _ = try await validateAccess(to: url)
        
        // Then start accessing
        return try await startAccessing(url)
    }
}
