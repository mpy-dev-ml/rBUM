//
//  DevelopmentBookmarkService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Development mock implementation of BookmarkServiceProtocol
/// Provides simulated bookmark behaviour for development
@available(macOS 13.0, *)
public final class DevelopmentBookmarkService: BookmarkServiceProtocol, @unchecked Sendable {
    // MARK: - Properties
    private let logger: LoggerProtocol
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.developmentBookmark", attributes: .concurrent)
    private var bookmarks: [URL: Data] = [:]
    private var activeAccess: Set<URL> = []
    private let configuration: DevelopmentConfiguration
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        configuration: DevelopmentConfiguration = .init()
    ) {
        self.logger = logger
        self.configuration = configuration
        
        logger.info(
            """
            Initialised DevelopmentBookmarkService with configuration: \
            \(String(describing: configuration))
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    // MARK: - BookmarkServiceProtocol Implementation
    public func createBookmark(for url: URL) throws -> Data {
        if configuration.shouldSimulateBookmarkFailures {
            logger.error(
                """
                Simulating bookmark creation failure for URL: \
                \(url.path)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            throw BookmarkError.creationFailed(url)
        }
        
        return queue.sync {
            let bookmarkData = Data("mock_bookmark_\(url.path)".utf8)
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
        if configuration.shouldSimulateBookmarkFailures {
            let urlString = bookmarks.first(where: { $0.value == bookmark })
                .map { $0.key.path }
                ?? "unknown"
                
            logger.error(
                """
                Simulating bookmark resolution failure for URL: \
                \(urlString)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            
            if let url = bookmarks.first(where: { $0.value == bookmark })?.key {
                throw BookmarkError.resolutionFailed(url)
            }
            // If we can't find the URL, use a default error
            throw BookmarkError.resolutionFailed(URL(fileURLWithPath: "/"))
        }
        
        return queue.sync {
            if let url = bookmarks.first(where: { $0.value == bookmark })?.key {
                logger.info(
                    "Resolved bookmark to URL: \(url.path)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return try! url.checkResourceIsReachable() ? 
                    url : URL(fileURLWithPath: "/")
            }
            return URL(fileURLWithPath: "/")
        }
    }
    
    private func validateBookmarkSync(_ bookmark: Data) throws -> Bool {
        if configuration.shouldSimulateBookmarkFailures {
            let urlString = bookmarks.first(where: { $0.value == bookmark })
                .map { $0.key.path }
                ?? "unknown"
                
            logger.error(
                """
                Simulating bookmark validation failure for URL: \
                \(urlString)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            
            if let url = bookmarks.first(where: { $0.value == bookmark })?.key {
                throw BookmarkError.invalidBookmark(url)
            }
            throw BookmarkError.invalidBookmark(URL(fileURLWithPath: "/"))
        }
        
        return queue.sync {
            // Check if bookmark exists and get corresponding URL
            guard let url = bookmarks.first(where: { $0.value == bookmark })?.key 
            else {
                return false
            }
            
            // Simulate failures if configured
            if configuration.shouldSimulateBookmarkFailures {
                return false
            }
            
            return true
        }
    }
    
    public func validateBookmark(_ bookmark: Data) throws -> Bool {
        return try validateBookmarkSync(bookmark)
    }
    
    private func startAccessingSync(_ url: URL) throws -> Bool {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating access failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw BookmarkError.accessDenied(url)
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
    
    public func startAccessing(_ url: URL) throws -> Bool {
        return try startAccessingSync(url)
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
