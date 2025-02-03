//
//  SecurityService.swift
//  rBUM
//
//  Created by Matthew Yeager on 01/02/2025.
//

import Foundation
import AppKit
import SystemConfiguration
import Security
import ApplicationServices
import Core
import OSLog

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

/// Implementation of SecurityService
public final class SecurityService: SecurityServiceProtocol {
    private let logger: LoggerProtocol
    private let fileManager: FileManager
    private let workspace: NSWorkspace
    
    /// Manages access to security-scoped resources
    private class SecurityScopedResourceAccess {
        private let url: URL
        private let logger: LoggerProtocol
        private var isAccessing: Bool = false
        
        init(url: URL, logger: LoggerProtocol) {
            self.url = url
            self.logger = logger
        }
        
        func start() -> Bool {
            guard !isAccessing else {
                logger.debug("Already accessing resource: \(url.path, privacy: .private)")
                return true
            }
            
            isAccessing = url.startAccessingSecurityScopedResource()
            if isAccessing {
                logger.debug("Started accessing resource: \(url.path, privacy: .private)")
            } else {
                logger.error("Failed to start accessing resource: \(url.path, privacy: .private)")
            }
            
            return isAccessing
        }
        
        func stop() {
            guard isAccessing else {
                logger.debug("Not currently accessing resource: \(url.path, privacy: .private)")
                return
            }
            
            url.stopAccessingSecurityScopedResource()
            isAccessing = false
            logger.debug("Stopped accessing resource: \(url.path, privacy: .private)")
        }
        
        deinit {
            if isAccessing {
                logger.warning("Resource access not properly stopped: \(url.path, privacy: .private)")
                stop()
            }
        }
    }
    
    /// Dictionary to track active security-scoped resource access
    private var activeAccess: [URL: SecurityScopedResourceAccess] = [:]
    
    /// Start accessing a security-scoped resource
    /// - Parameter url: The URL to access
    /// - Returns: true if access was granted, false otherwise
    func startAccessing(_ url: URL) -> Bool {
        let access = activeAccess[url] ?? SecurityScopedResourceAccess(url: url, logger: logger)
        activeAccess[url] = access
        return access.start()
    }
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    func stopAccessing(_ url: URL) {
        activeAccess[url]?.stop()
        activeAccess[url] = nil
    }
    
    public init(
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "Security") as! LoggerProtocol,
        fileManager: FileManager = .default,
        workspace: NSWorkspace = .shared
    ) {
        self.logger = logger
        self.fileManager = fileManager
        self.workspace = workspace
        
        logger.debug("Security service initialised")
    }
    
    public func requestPermission(for url: URL) async throws -> Bool {
        logger.info("Requesting permission for path: \(url.path, privacy: .private)")
        
        do {
            let bookmark = try await createBookmark(for: url)
            logger.debug("Created bookmark for path: \(url.path, privacy: .private)")
            
            // Start accessing immediately to verify access
            guard startAccessing(url) else {
                logger.error("Failed to access resource after creating bookmark: \(url.path, privacy: .private)")
                throw SecurityError.accessDenied(url.path)
            }
            
            // Stop accessing since we're just verifying
            stopAccessing(url)
            return true
            
        } catch {
            logger.error("Failed to request permission: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }
    
    public func revokePermission(for url: URL) async throws {
        logger.info("Revoking permission for path: \(url.path, privacy: .private)")
        
        do {
            try await bookmarkService.deleteBookmark(for: url)
            logger.debug("Revoked permission for path: \(url.path, privacy: .private)")
        } catch {
            logger.error("Failed to revoke permission: \(error.localizedDescription, privacy: .private)")
            throw SecurityError.revocationFailed(url.path)
        }
    }
    
    public func requestFullDiskAccess() async throws -> Bool {
        logger.info("Requesting Full Disk Access")
        
        guard !(await checkFullDiskAccess()) else {
            return true
        }
        
        // Open System Settings to Security & Privacy
        let prefpaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        let opened = await MainActor.run {
            workspace.open(prefpaneURL)
        }
        
        if !opened {
            logger.error("Failed to open System Settings")
        }
        
        // Show instructions to the user
        throw SecurityError.needsFullDiskAccess(
            "Full Disk Access is required for backup operations.\n" +
            "Please grant access in System Settings > Privacy & Security > Full Disk Access"
        )
    }
    
    public func checkFullDiskAccess() async -> Bool {
        logger.debug("Checking Full Disk Access permission")
        
        // Test by attempting to read a protected directory
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let testPath = homeDir.appendingPathComponent("Library/Application Support")
        
        do {
            _ = try fileManager.contentsOfDirectory(atPath: testPath.path)
            return true
        } catch {
            logger.error("Full Disk Access check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    public func requestAutomation() async throws -> Bool {
        logger.info("Requesting Automation permission")
        
        guard !(await checkAutomation()) else {
            return true
        }
        
        // Open System Settings to Security & Privacy > Automation
        let prefpaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        let opened = await MainActor.run {
            workspace.open(prefpaneURL)
        }
        
        if !opened {
            logger.error("Failed to open System Settings")
        }
        
        throw SecurityError.needsAutomation(
            "Automation access is required for some backup operations.\n" +
            "Please grant access in System Settings > Privacy & Security > Automation"
        )
    }
    
    public func checkAutomation() async -> Bool {
        logger.debug("Checking Automation permission")
        
        return await Task {
            // Use AXIsProcessTrusted() to check if we have automation access
            let isTrusted = AXIsProcessTrusted()
            
            if !isTrusted {
                logger.warning("Automation access not granted")
                return false
            }
            
            logger.info("Automation access granted")
            return true
        }.value
    }
    
    public func createBookmark(for url: URL) async throws -> Data {
        logger.debug("Creating bookmark for path: \(url.path)")
        
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            logger.error("Failed to create bookmark: \(error.localizedDescription)")
            throw SecurityError.bookmarkCreationFailed(error.localizedDescription)
        }
    }
    
    public func resolveBookmark(_ data: Data) async throws -> URL {
        logger.debug("Resolving bookmark")
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                logger.error("Bookmark is stale for URL: \(url.path)")
                throw SecurityError.staleBookmark(url.path)
            }
            
            logger.debug("Successfully resolved bookmark to path: \(url.path)")
            return url
        } catch {
            logger.error("Failed to resolve bookmark: \(error.localizedDescription)")
            throw SecurityError.bookmarkResolutionFailed(error.localizedDescription)
        }
    }
    
    public func checkAccess(to url: URL) -> Bool {
        logger.debug("Checking access to path: \(url.path)")
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isReadableKey, .isWritableKey])
            return resourceValues.isReadable == true
        } catch {
            logger.error("Failed to check access: \(error.localizedDescription)")
            return false
        }
    }
}

/// Errors that can occur during security operations
public enum SecurityError: LocalizedError {
    case needsFullDiskAccess(String)
    case needsAutomation(String)
    case bookmarkCreationFailed(String)
    case bookmarkResolutionFailed(String)
    case staleBookmark(String)
    case permissionDenied(String)
    case revocationFailed(String)
    case accessDenied(String)
    
    public var errorDescription: String? {
        switch self {
        case .needsFullDiskAccess(let message):
            return "Full Disk Access Required: \(message)"
        case .needsAutomation(let message):
            return "Automation Access Required: \(message)"
        case .bookmarkCreationFailed(let message):
            return "Failed to create security bookmark: \(message)"
        case .bookmarkResolutionFailed(let message):
            return "Failed to resolve security bookmark: \(message)"
        case .staleBookmark(let path):
            return "Security bookmark is stale for path: \(path)"
        case .permissionDenied(let path):
            return "Permission denied for path: \(path)"
        case .revocationFailed(let path):
            return "Failed to revoke permission for path: \(path)"
        case .accessDenied(let path):
            return "Access denied for path: \(path)"
        }
    }
}
