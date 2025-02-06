//
//  DevelopmentBookmarkService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Development mock implementation of BookmarkServiceProtocol
/// Provides in-memory storage and configurable behaviour for development
public final class DevelopmentBookmarkService: BookmarkServiceProtocol {
    // MARK: - Properties
    private let logger: LoggerProtocol
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.developmentBookmark", attributes: .concurrent)
    private var bookmarks: [URL: Data] = [:]
    private var activeAccess: Set<URL> = []
    
    /// Configuration for simulating bookmark behaviour
    public struct Configuration {
        /// Whether to simulate bookmark creation failures
        public var shouldSimulateCreationFailures: Bool
        /// Whether to simulate bookmark resolution failures
        public var shouldSimulateResolutionFailures: Bool
        /// Whether to simulate bookmark validation failures
        public var shouldSimulateValidationFailures: Bool
        /// Whether to simulate access failures
        public var shouldSimulateAccessFailures: Bool
        /// Artificial delay for operations (seconds)
        public var artificialDelay: TimeInterval
        /// Percentage of bookmarks that should be considered stale (0-100)
        public var stalenessPercentage: Double
        
        public init(
            shouldSimulateCreationFailures: Bool = false,
            shouldSimulateResolutionFailures: Bool = false,
            shouldSimulateValidationFailures: Bool = false,
            shouldSimulateAccessFailures: Bool = false,
            artificialDelay: TimeInterval = 0,
            stalenessPercentage: Double = 0
        ) {
            self.shouldSimulateCreationFailures = shouldSimulateCreationFailures
            self.shouldSimulateResolutionFailures = shouldSimulateResolutionFailures
            self.shouldSimulateValidationFailures = shouldSimulateValidationFailures
            self.shouldSimulateAccessFailures = shouldSimulateAccessFailures
            self.artificialDelay = artificialDelay
            self.stalenessPercentage = max(0, min(100, stalenessPercentage))
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
            "Initialised DevelopmentBookmarkService with configuration: \(String(describing: configuration))",
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    // MARK: - BookmarkServiceProtocol Implementation
    public func createBookmark(for url: URL) throws -> Data {
        if configuration.shouldSimulateCreationFailures {
            logger.error(
                "Simulating bookmark creation failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw BookmarkError.creationFailed
        }
        
        return queue.sync {
            let bookmarkData = "mock_bookmark_\(url.path)".data(using: .utf8)!
            bookmarks[url] = bookmarkData
            logger.info(
                "Created bookmark for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            return bookmarkData
        }
    }
    
    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        if configuration.shouldSimulateResolutionFailures {
            logger.error(
                "Simulating bookmark resolution failure",
                file: #file,
                function: #function,
                line: #line
            )
            throw BookmarkError.resolutionFailed
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
            throw BookmarkError.resolutionFailed
        }
    }
    
    public func validateBookmark(_ bookmark: Data) throws -> Bool {
        if configuration.shouldSimulateValidationFailures {
            logger.error(
                "Simulating bookmark validation failure",
                file: #file,
                function: #function,
                line: #line
            )
            throw BookmarkError.validationFailed
        }
        
        return queue.sync {
            if let url = bookmarks.first(where: { $0.value == bookmark })?.key {
                // Simulate staleness based on configuration
                let isStale = Double.random(in: 0...100) < configuration.stalenessPercentage
                logger.info(
                    "Validated bookmark for URL: \(url.path), isValid: \(!isStale)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return !isStale
            }
            return false
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
            throw BookmarkError.accessDenied
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
