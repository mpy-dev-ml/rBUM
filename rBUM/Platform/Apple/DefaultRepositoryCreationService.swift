//
//  DefaultRepositoryCreationService.swift
//  rBUM
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation
import Core

/// Service for creating and managing default repository locations on macOS
public final class DefaultRepositoryCreationService: BaseSandboxedService, DefaultRepositoryCreationProtocol, HealthCheckable {
    // MARK: - Properties
    private let bookmarkService: BookmarkServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let operationQueue: OperationQueue
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.defaultRepository", attributes: .concurrent)
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
        keychainService: KeychainServiceProtocol
    ) {
        self.bookmarkService = bookmarkService
        self.keychainService = keychainService
        
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "dev.mpy.rBUM.defaultRepositoryQueue"
        self.operationQueue.maxConcurrentOperationCount = 1
        
        super.init(logger: logger, securityService: securityService)
    }
    
    // MARK: - DefaultRepositoryCreationProtocol Implementation
    public func createDefaultRepository() async throws -> URL {
        let operationId = UUID()
        
        return try await measure("Create Default Repository") {
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
                // Get application support directory
                let appSupport = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                
                // Create repository directory
                let repositoryURL = appSupport.appendingPathComponent("Repositories", isDirectory: true)
                    .appendingPathComponent("Default", isDirectory: true)
                
                try FileManager.default.createDirectory(
                    at: repositoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                
                // Create and store bookmark
                let bookmark = try await bookmarkService.createBookmark(for: repositoryURL)
                try keychainService.storeBookmark(bookmark, for: repositoryURL)
                
                logger.info("Created default repository at \(repositoryURL.path)")
                return repositoryURL
            } catch {
                logger.error("Failed to create default repository: \(error.localizedDescription)")
                throw RepositoryCreationError.creationFailed(error.localizedDescription)
            }
        }
    }
    
    public func getDefaultRepositoryLocation() async throws -> URL? {
        try await measure("Get Default Repository Location") {
            do {
                // Get application support directory
                let appSupport = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: false
                )
                
                let repositoryURL = appSupport.appendingPathComponent("Repositories", isDirectory: true)
                    .appendingPathComponent("Default", isDirectory: true)
                
                // Check if directory exists
                guard FileManager.default.fileExists(atPath: repositoryURL.path) else {
                    logger.info("Default repository not found")
                    return nil
                }
                
                // Validate bookmark
                guard try await bookmarkService.validateBookmark(for: repositoryURL) else {
                    logger.warning("Invalid bookmark for default repository")
                    return nil
                }
                
                logger.info("Found default repository at \(repositoryURL.path)")
                return repositoryURL
            } catch {
                logger.error("Failed to get default repository location: \(error.localizedDescription)")
                throw RepositoryCreationError.locationError(error.localizedDescription)
            }
        }
    }
    
    public func validateDefaultRepository() async throws -> Bool {
        try await measure("Validate Default Repository") {
            do {
                guard let repositoryURL = try await getDefaultRepositoryLocation() else {
                    return false
                }
                
                // Check directory permissions
                guard await securityService.checkAccess(to: repositoryURL) else {
                    logger.warning("No access to default repository")
                    return false
                }
                
                // Check directory attributes
                let attributes = try FileManager.default.attributesOfItem(atPath: repositoryURL.path)
                guard let type = attributes[.type] as? FileAttributeType,
                      type == .typeDirectory else {
                    logger.warning("Default repository is not a directory")
                    return false
                }
                
                logger.info("Successfully validated default repository")
                return true
            } catch {
                logger.error("Failed to validate default repository: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Default Repository Creation Service Health Check") {
            do {
                // Check dependencies
                guard await bookmarkService.performHealthCheck(),
                      await keychainService.performHealthCheck() else {
                    return false
                }
                
                // Check for stuck operations
                let stuckOperations = accessQueue.sync { activeOperations }
                if !stuckOperations.isEmpty {
                    logger.warning("Found \(stuckOperations.count) potentially stuck operations")
                    return false
                }
                
                // Validate default repository if it exists
                if let _ = try? await getDefaultRepositoryLocation() {
                    guard try await validateDefaultRepository() else {
                        return false
                    }
                }
                
                logger.info("Default repository creation service health check passed")
                return true
            } catch {
                logger.error("Default repository creation service health check failed: \(error.localizedDescription)")
                return false
            }
        }
    }
}

// MARK: - Repository Creation Errors
public enum RepositoryCreationError: LocalizedError {
    case creationFailed(String)
    case locationError(String)
    case validationError(String)
    case accessDenied
    
    public var errorDescription: String? {
        switch self {
        case .creationFailed(let message):
            return "Failed to create repository: \(message)"
        case .locationError(let message):
            return "Failed to access repository location: \(message)"
        case .validationError(let message):
            return "Repository validation failed: \(message)"
        case .accessDenied:
            return "Access denied to repository location"
        }
    }
}
