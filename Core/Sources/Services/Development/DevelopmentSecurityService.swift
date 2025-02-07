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
    public func startAccessing(_ url: URL) throws -> Bool {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating access failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.accessDenied("Failed to start accessing URL (simulated)")
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
    
    // MARK: - Properties
    private let logger: LoggerProtocol
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.developmentSecurity", attributes: .concurrent)
    private var bookmarks: [URL: Data] = [:]
    private var activeAccess: Set<URL> = []
    private let configuration: DevelopmentConfiguration
    
    // MARK: - Initialization
    public init(logger: LoggerProtocol, configuration: DevelopmentConfiguration = .default) {
        self.logger = logger
        self.configuration = configuration
    }
    
    // MARK: - SecurityServiceProtocol Implementation
    public func validateAccess(to url: URL) async throws -> Bool {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating access validation failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.accessDenied("Access denied (simulated)")
        }
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        logger.info(
            "Validating access to URL: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    public func persistAccess(to url: URL) async throws -> Data {
        if configuration.shouldSimulateBookmarkFailures {
            logger.error(
                "Simulating bookmark creation failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.bookmarkCreationFailed("Failed to create bookmark (simulated)")
        }
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        return try queue.sync {
            let string = "mock-bookmark-\(UUID().uuidString)"
            guard let bookmark = string.data(using: .utf8) else {
                logger.error(
                    "Failed to create bookmark data",
                    file: #file,
                    function: #function,
                    line: #line
                )
                throw SecurityError.bookmarkCreationFailed("Failed to create bookmark data")
            }
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
    
    public func validateXPCConnection(_ connection: NSXPCConnection) async throws -> Bool {
        if configuration.shouldSimulateConnectionFailures {
            logger.error(
                "Simulating XPC connection validation failure",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.xpcConnectionFailed("XPC connection validation failed (simulated)")
        }
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        logger.info(
            "Validated XPC connection",
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    public func validateXPCService() async throws -> Bool {
        // Implementation
        return true
    }
    
    public func requestPermission(for url: URL) async throws -> Bool {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating permission request failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.accessDenied("Permission denied (simulated)")
        }
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        logger.info(
            "Granting permission for URL: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    public func createBookmark(for url: URL) throws -> Data {
        if configuration.shouldSimulateBookmarkFailures {
            logger.error(
                "Simulating bookmark creation failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.bookmarkCreationFailed("Failed to create bookmark (simulated)")
        }
        
        return try queue.sync {
            let string = "mock-bookmark-\(UUID().uuidString)"
            guard let bookmark = string.data(using: .utf8) else {
                logger.error(
                    "Failed to create bookmark data",
                    file: #file,
                    function: #function,
                    line: #line
                )
                throw SecurityError.bookmarkCreationFailed("Failed to create bookmark data")
            }
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
            throw SecurityError.bookmarkResolutionFailed("Failed to resolve bookmark (simulated)")
        }
        
        return try queue.sync {
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
            throw SecurityError.bookmarkResolutionFailed("Bookmark not found")
        }
    }
    
    public func startAccessing(_ url: URL) async throws -> Bool {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating access start failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.accessDenied("Failed to start accessing URL (simulated)")
        }
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.activeAccess.insert(url)
                self.logger.info(
                    "Started accessing URL: \(url.path)",
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
                self.logger.info(
                    "Stopped accessing URL: \(url.path)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                continuation.resume()
            }
        }
    }
    
    public func validateAndStartAccessing(_ url: URL) async throws -> Bool {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating validate and access start failure for URL: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.accessDenied("Failed to validate and start accessing URL (simulated)")
        }
        
        if configuration.artificialDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000))
        }
        
        // First validate access
        _ = try await validateAccess(to: url)
        
        // Then start accessing
        return try await startAccessing(url)
    }
}
