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
    
    public init(
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "Security"),
        fileManager: FileManager = .default,
        workspace: NSWorkspace = .shared
    ) {
        self.logger = logger
        self.fileManager = fileManager
        self.workspace = workspace
        
        logger.debug("Security service initialised", privacy: .public)
    }
    
    public func requestPermission(for url: URL) async throws -> Bool {
        logger.debug("Requesting permission for: \(url.path, privacy: .public)")
        
        return await MainActor.run { @MainActor in
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = url.hasDirectoryPath ? false : true
            openPanel.canChooseDirectories = url.hasDirectoryPath
            openPanel.allowsMultipleSelection = false
            openPanel.canCreateDirectories = false
            openPanel.directoryURL = url.deletingLastPathComponent()
            openPanel.message = "Grant access to \(url.lastPathComponent)"
            openPanel.prompt = "Grant Access"
            
            let response = openPanel.runModal()
            guard response == .OK else {
                logger.warning("Permission request cancelled by user")
                return false
            }
            
            guard let selectedURL = openPanel.url, selectedURL == url else {
                logger.warning("Selected URL does not match requested URL")
                return false
            }
            
            // Start accessing the security-scoped resource
            let hasAccess = selectedURL.startAccessingSecurityScopedResource()
            if !hasAccess {
                logger.error("Failed to access security-scoped resource")
            }
            return hasAccess
        }
    }
    
    public func revokePermission(for url: URL) async throws {
        logger.debug("Revoking permission for: \(url.path, privacy: .public)")
        url.stopAccessingSecurityScopedResource()
    }
    
    public func requestFullDiskAccess() async throws -> Bool {
        logger.debug("Requesting Full Disk Access")
        
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
        logger.debug("Checking Full Disk Access")
        
        // Test by attempting to read a protected directory
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let testPath = homeDir.appendingPathComponent("Library/Application Support")
        
        do {
            _ = try fileManager.contentsOfDirectory(atPath: testPath.path)
            return true
        } catch {
            logger.error("Full Disk Access check failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    public func requestAutomation() async throws -> Bool {
        logger.debug("Requesting Automation permission")
        
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
        logger.debug("Creating bookmark for: \(url.path, privacy: .public)")
        
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            logger.error("Failed to create bookmark: \(error.localizedDescription, privacy: .public)")
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
                logger.error("Bookmark is stale for URL: \(url.path, privacy: .public)")
                throw SecurityError.staleBookmark(url.path)
            }
            
            return url
        } catch {
            logger.error("Failed to resolve bookmark: \(error.localizedDescription, privacy: .public)")
            throw SecurityError.bookmarkResolutionFailed(error.localizedDescription)
        }
    }
    
    public func checkAccess(to url: URL) -> Bool {
        logger.debug("Checking access to: \(url.path, privacy: .public)")
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isReadableKey, .isWritableKey])
            return resourceValues.isReadable == true
        } catch {
            logger.error("Failed to check access: \(error.localizedDescription, privacy: .public)")
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
        }
    }
}
