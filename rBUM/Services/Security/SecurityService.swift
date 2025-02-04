//
//  SecurityService.swift
//  rBUM
//
//  Created by Matthew Yeager on 01/02/2025.
//

import Foundation
import Core

/// Service responsible for handling security and sandbox-related operations
public final class SecurityService: BaseSandboxedService, SecurityServiceProtocol, HealthCheckable {
    // MARK: - Properties
    private let bookmarkStore: [URL: Data] = [:]
    private let accessQueue: DispatchQueue
    
    public var isHealthy: Bool {
        true // Override with actual health check logic
    }
    
    // MARK: - Initialization
    public init(logger: LoggerProtocol) {
        self.accessQueue = DispatchQueue(label: "dev.mpy.rBUM.securityService", attributes: .concurrent)
        super.init(logger: logger, securityService: self)
    }
    
    // MARK: - SecurityServiceProtocol Implementation
    public func validateBookmark(_ bookmark: Data) throws -> URL {
        try measure("Validate Bookmark") {
            var isStale = false
            guard let url = try URL(resolvingBookmarkData: bookmark,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) else {
                throw ServiceError.operationFailed
            }
            
            if isStale {
                logger.warning("Bookmark for \(url.path) is stale")
                throw SandboxError.bookmarkStale
            }
            
            return url
        }
    }
    
    public func persistBookmark(for url: URL) throws -> Data {
        try measure("Persist Bookmark") {
            try url.bookmarkData(options: .withSecurityScope,
                               includingResourceValuesForKeys: nil,
                               relativeTo: nil)
        }
    }
    
    public func startAccessing(_ url: URL) -> Bool {
        accessQueue.sync {
            logger.debug("Starting access to \(url.path)")
            return url.startAccessingSecurityScopedResource()
        }
    }
    
    public func stopAccessing(_ url: URL) {
        accessQueue.async {
            self.logger.debug("Stopping access to \(url.path)")
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Security Service Health Check") {
            // Add actual health check implementation
            // For example, verify bookmark store integrity
            true
        }
    }
    
    // MARK: - Resource Management
    public func withSafeAccess<T>(to url: URL, perform action: () throws -> T) throws -> T {
        try accessQueue.sync {
            guard startAccessing(url) else {
                throw SandboxError.accessDenied
            }
            defer { stopAccessing(url) }
            return try action()
        }
    }
    
    public func withSafeAccess<T>(to url: URL, perform action: () async throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            accessQueue.async {
                guard self.startAccessing(url) else {
                    continuation.resume(throwing: SandboxError.accessDenied)
                    return
                }
                defer { self.stopAccessing(url) }
                
                Task {
                    do {
                        let result = try await action()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

/// Protocol defining security-related operations for the application
public protocol SecurityServiceProtocol {
    /// Request permission for a specific file or directory
    func requestPermission(for url: URL) async throws -> Bool
    
    /// Revoke permission for a specific file or directory
    func revokePermission(for url: URL) async throws
    
    /// Request Full Disk Access permission
    func requestFullDiskAccess() async throws -> Bool
    
    /// Check if Full Disk Access permission is granted
    func checkFullDiskAccess() async -> Bool
    
    /// Request Automation permission for the application
    func requestAutomation() async throws -> Bool
    
    /// Check if Automation permission is granted
    func checkAutomation() async -> Bool
    
    /// Create a security-scoped bookmark for a URL
    func createBookmark(for url: URL) async throws -> Data
    
    /// Resolve a security-scoped bookmark to a URL
    func resolveBookmark(_ data: Data) async throws -> URL
    
    /// Check if we have access to a specific path
    func checkAccess(to url: URL) -> Bool
}

/// Default implementation of SecurityServiceProtocol
public final class DefaultSecurityService: SecurityServiceProtocol {
    private let bookmarkService: BookmarkServiceProtocol
    private let logger: LoggerProtocol
    
    public init(
        bookmarkService: BookmarkServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.bookmarkService = bookmarkService
        self.logger = logger
    }
    
    public func createBookmark(for url: URL) throws -> Data {
        try bookmarkService.createBookmark(for: url)
    }
    
    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        try bookmarkService.resolveBookmark(bookmark)
    }
    
    public func validateAccess(to url: URL) throws {
        try bookmarkService.validateAccess(to: url)
    }
    
    public func startAccessing(_ url: URL) -> Bool {
        do {
            try validateAccess(to: url)
            return url.startAccessingSecurityScopedResource()
        } catch {
            logger.error("Failed to start accessing resource: \(error.localizedDescription)")
            return false
        }
    }
    
    public func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
