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
public final class DevelopmentSecurityService: SecurityServiceProtocol {
    // MARK: - Properties
    private let logger: LoggerProtocol
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.developmentSecurity", attributes: .concurrent)
    private var activeAccess: Set<URL> = []
    private var bookmarks: [URL: Data] = [:]
    private var permissions: [URL: Bool] = [:]
    
    /// Configuration for simulating failures
    public struct Configuration {
        /// Whether to simulate permission failures
        public var shouldSimulatePermissionFailures: Bool
        /// Whether to simulate bookmark failures
        public var shouldSimulateBookmarkFailures: Bool
        /// Whether to simulate access failures
        public var shouldSimulateAccessFailures: Bool
        /// Artificial delay for async operations (seconds)
        public var artificialDelay: TimeInterval
        
        public init(
            shouldSimulatePermissionFailures: Bool = false,
            shouldSimulateBookmarkFailures: Bool = false,
            shouldSimulateAccessFailures: Bool = false,
            artificialDelay: TimeInterval = 0
        ) {
            self.shouldSimulatePermissionFailures = shouldSimulatePermissionFailures
            self.shouldSimulateBookmarkFailures = shouldSimulateBookmarkFailures
            self.shouldSimulateAccessFailures = shouldSimulateAccessFailures
            self.artificialDelay = artificialDelay
        }
    }
    
    private var configuration: Configuration
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        configuration: Configuration = Configuration()
    ) {
        self.logger = logger
        self.configuration = configuration
        
        logger.info(
            "Initialised DevelopmentSecurityService with configuration: \(String(describing: configuration))",
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    // MARK: - SecurityServiceProtocol Implementation
    public func requestPermission(for url: URL) async throws -> Bool {
        if configuration.shouldSimulatePermissionFailures {
            logger.error(
                "Simulating permission failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.permissionDenied
        }
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        return queue.sync {
            permissions[url] = true
            logger.info(
                "Granted permission for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            return true
        }
    }
    
    public func createBookmark(for url: URL) throws -> Data {
        if configuration.shouldSimulateBookmarkFailures {
            logger.error(
                "Simulating bookmark creation failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.bookmarkCreationFailed
        }
        
        return queue.sync {
            let bookmark = "mock_bookmark_\(url.path)".data(using: .utf8)!
            bookmarks[url] = bookmark
            logger.info(
                "Created bookmark for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            return bookmark
        }
    }
    
    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        if configuration.shouldSimulateBookmarkFailures {
            logger.error(
                "Simulating bookmark resolution failure",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.bookmarkResolutionFailed
        }
        
        return queue.sync {
            if let url = bookmarks.first(where: { $0.value == bookmark })?.key {
                logger.info(
                    "Resolved bookmark to URL: \(url.path)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return url
            }
            
            logger.error(
                "Failed to resolve bookmark",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.bookmarkResolutionFailed
        }
    }
    
    public func startAccessing(_ url: URL) throws -> Bool {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating access failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.accessDenied
        }
        
        return queue.sync {
            activeAccess.insert(url)
            logger.info(
                "Started accessing URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            return true
        }
    }
    
    public func stopAccessing(_ url: URL) async throws {
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        queue.async(flags: .barrier) {
            self.activeAccess.remove(url)
            self.logger.info(
                "Stopped accessing URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
}
