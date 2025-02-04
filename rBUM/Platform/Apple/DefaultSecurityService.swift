//
//  DefaultSecurityService.swift
//  rBUM
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation
import Core
import Security

/// macOS-specific implementation of security service
public final class DefaultSecurityService: BaseSandboxedService, SecurityServiceProtocol, HealthCheckable {
    // MARK: - Properties
    private let bookmarkService: BookmarkServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let sandboxMonitor: SandboxMonitorProtocol
    private let operationQueue: OperationQueue
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.defaultSecurity", attributes: .concurrent)
    private var activeOperations: Set<UUID> = []
    
    public var isHealthy: Bool {
        // Check if we have any stuck operations
        accessQueue.sync {
            activeOperations.isEmpty
        }
    }
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        bookmarkService: BookmarkServiceProtocol,
        keychainService: KeychainServiceProtocol,
        sandboxMonitor: SandboxMonitorProtocol
    ) {
        self.bookmarkService = bookmarkService
        self.keychainService = keychainService
        self.sandboxMonitor = sandboxMonitor
        
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "dev.mpy.rBUM.defaultSecurityQueue"
        self.operationQueue.maxConcurrentOperationCount = 1
        
        super.init(logger: logger, securityService: securityService)
    }
    
    // MARK: - SecurityServiceProtocol Implementation
    public func validateAccess(to url: URL) async throws -> Bool {
        try await measure("Validate Access") {
            do {
                // Check if we have a valid bookmark
                guard try await bookmarkService.validateBookmark(for: url) else {
                    logger.warning("No valid bookmark for \(url.path)")
                    return false
                }
                
                // Check file system attributes
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                guard let posixPermissions = attributes[.posixPermissions] as? Int else {
                    logger.warning("Could not get POSIX permissions for \(url.path)")
                    return false
                }
                
                // Check if we have read access (owner read permission)
                let hasReadAccess = (posixPermissions & 0o400) != 0
                if !hasReadAccess {
                    logger.warning("No read permission for \(url.path)")
                    return false
                }
                
                logger.info("Successfully validated access to \(url.path)")
                return true
            } catch {
                logger.error("Failed to validate access: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    public func requestAccess(to url: URL) async throws -> Bool {
        let operationId = UUID()
        
        return try await measure("Request Access") {
            // Track operation
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            do {
                // Try to create bookmark if we don't have one
                if !(try await bookmarkService.validateBookmark(for: url)) {
                    _ = try await bookmarkService.createBookmark(for: url)
                }
                
                // Start tracking access
                sandboxMonitor.trackResourceAccess(to: url)
                
                // Start accessing the resource
                guard try await bookmarkService.startAccessing(url) else {
                    logger.warning("Failed to start accessing \(url.path)")
                    return false
                }
                
                logger.info("Successfully requested access to \(url.path)")
                return true
            } catch {
                logger.error("Failed to request access: \(error.localizedDescription)")
                throw SecurityError.accessDenied(error.localizedDescription)
            }
        }
    }
    
    public func revokeAccess(to url: URL) {
        let operationId = UUID()
        
        measure("Revoke Access") {
            // Track operation
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }
            
            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }
            
            // Stop tracking access
            sandboxMonitor.stopTrackingResource(url)
            
            // Stop accessing the resource
            bookmarkService.stopAccessing(url)
            
            logger.info("Revoked access to \(url.path)")
        }
    }
    
    public func validateEncryption() async throws -> Bool {
        try await measure("Validate Encryption") {
            do {
                // Check if keychain is accessible
                guard await keychainService.performHealthCheck() else {
                    logger.warning("Keychain health check failed")
                    return false
                }
                
                // Check if we can store and retrieve a test item
                let testData = "test".data(using: .utf8)!
                try keychainService.storeGenericPassword(testData, service: "test", account: "test")
                let retrieved = try keychainService.retrieveGenericPassword(service: "test", account: "test")
                
                guard retrieved == testData else {
                    logger.warning("Keychain data integrity check failed")
                    return false
                }
                
                // Clean up test item
                try keychainService.deleteGenericPassword(service: "test", account: "test")
                
                logger.info("Successfully validated encryption")
                return true
            } catch {
                logger.error("Failed to validate encryption: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Default Security Service Health Check") {
            do {
                // Check dependencies
                guard await bookmarkService.performHealthCheck(),
                      await keychainService.performHealthCheck(),
                      await sandboxMonitor.performHealthCheck() else {
                    return false
                }
                
                // Check for stuck operations
                let stuckOperations = accessQueue.sync { activeOperations }
                if !stuckOperations.isEmpty {
                    logger.warning("Found \(stuckOperations.count) potentially stuck operations")
                    return false
                }
                
                // Validate encryption
                guard try await validateEncryption() else {
                    return false
                }
                
                logger.info("Default security service health check passed")
                return true
            } catch {
                logger.error("Default security service health check failed: \(error.localizedDescription)")
                return false
            }
        }
    }
}

// MARK: - Security Errors
public enum SecurityError: LocalizedError {
    case accessDenied(String)
    case encryptionError(String)
    case bookmarkError(String)
    case monitorError(String)
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied(let message):
            return "Access denied: \(message)"
        case .encryptionError(let message):
            return "Encryption error: \(message)"
        case .bookmarkError(let message):
            return "Bookmark error: \(message)"
        case .monitorError(let message):
            return "Monitor error: \(message)"
        }
    }
}
