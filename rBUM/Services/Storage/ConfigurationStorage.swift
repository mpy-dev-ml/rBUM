//
//  ConfigurationStorage.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Protocol for managing configuration storage
protocol ConfigurationStorageProtocol {
    /// Load the current configuration
    /// - Returns: The current configuration
    /// - Throws: StorageError if loading fails
    func load() throws -> Configuration
    
    /// Save the configuration
    /// - Parameter configuration: The configuration to save
    /// - Throws: StorageError if saving fails
    func save(_ configuration: Configuration) throws
    
    /// Reset configuration to default values
    /// - Throws: StorageError if reset fails
    func reset() throws
}

/// Error types for configuration storage operations
enum ConfigurationStorageError: LocalizedError, Equatable {
    case fileOperationFailed(String)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .fileOperationFailed(let operation):
            return "Failed to \(operation) configuration file"
        case .invalidData:
            return "Invalid configuration data format"
        }
    }
}

/// Error types for storage service operations
enum StorageError: LocalizedError, Equatable {
    case fileOperationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileOperationFailed(let operation):
            return "Failed to \(operation) data"
        }
    }
}

/// FileSystem-based implementation of ConfigurationStorageProtocol
final class ConfigurationStorage: ConfigurationStorageProtocol, StorageServiceProtocol {
    // MARK: - Properties
    
    private let fileManager: FileManagerProtocol
    private let logger: LoggerProtocol
    private let securityService: SecurityServiceProtocol
    private let dateProvider: DateProviderProtocol
    private let notificationCenter: NotificationCenter
    private let configURL: URL
    
    // MARK: - Initialization
    
    init(
        fileManager: FileManagerProtocol = FileManager.default as! FileManagerProtocol,
        logger: LoggerProtocol = OSLogger(category: "configuration"),
        securityService: SecurityServiceProtocol = {
            let logger = OSLogger(category: "security")
            // Step 1: Create temporary security service with mock XPC
            let tempSecurityService = SecurityService(
                logger: logger,
                xpcService: MockResticXPCService()
            )
            
            // Step 2: Create real XPC service using temporary security service
            let xpcService = ResticXPCService(
                logger: logger,
                securityService: tempSecurityService
            )
            
            // Step 3: Create final security service with real XPC service
            return SecurityService(
                logger: logger,
                xpcService: xpcService as! ResticXPCServiceProtocol
            )
        }(),
        dateProvider: DateProviderProtocol = DateProvider(),
        notificationCenter: NotificationCenter = .default
    ) throws {
        self.fileManager = fileManager
        self.logger = logger
        self.securityService = securityService
        self.dateProvider = dateProvider
        self.notificationCenter = notificationCenter
        
        // Get application support directory
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get application support directory", file: #file, function: #function, line: #line)
            throw StorageError.fileOperationFailed("Failed to get application support directory")
        }
        
        // Create configuration directory
        let configDir = appSupport.appendingPathComponent("dev.mpy.rBUM/Configuration", isDirectory: true)
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        // Set config file URL
        self.configURL = configDir.appendingPathComponent("config.json")
        
        logger.debug("Configuration storage initialized at \(configURL.path)", file: #file, function: #function, line: #line)
    }
    
    // MARK: - ConfigurationStorageProtocol Implementation
    
    func load() throws -> Configuration {
        logger.debug("Loading configuration", file: #file, function: #function, line: #line)
        
        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(Configuration.self, from: data)
        } catch {
            logger.error("Failed to load configuration: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw StorageError.fileOperationFailed("Failed to load configuration")
        }
    }
    
    func save(_ configuration: Configuration) throws {
        logger.debug("Saving configuration", file: #file, function: #function, line: #line)
        
        do {
            let data = try JSONEncoder().encode(configuration)
            try data.write(to: configURL, options: .atomic)
        } catch {
            logger.error("Failed to save configuration: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw StorageError.fileOperationFailed("Failed to save configuration")
        }
    }
    
    func reset() throws {
        logger.debug("Resetting configuration", file: #file, function: #function, line: #line)
        
        do {
            if FileManager.default.fileExists(atPath: configURL.path) {
                try FileManager.default.removeItem(at: configURL)
            }
            
            logger.debug("Successfully reset configuration", file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to reset configuration: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw StorageError.fileOperationFailed("Failed to reset configuration")
        }
    }
    
    // MARK: - StorageServiceProtocol Implementation
    
    func save(_ data: Data, forKey key: String) throws {
        logger.debug("Saving data for key: \(key)", file: #file, function: #function, line: #line)
        
        do {
            try data.write(to: configURL, options: .atomic)
        } catch {
            logger.error("Failed to save data: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw StorageError.fileOperationFailed("Failed to save data")
        }
    }
    
    func load(forKey key: String) throws -> Data {
        logger.debug("Loading data for key: \(key)", file: #file, function: #function, line: #line)
        
        do {
            return try Data(contentsOf: configURL)
        } catch {
            logger.error("Failed to load data: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw StorageError.fileOperationFailed("Failed to load data")
        }
    }
    
    func delete(forKey key: String) throws {
        logger.debug("Deleting data for key: \(key)", file: #file, function: #function, line: #line)
        
        do {
            try FileManager.default.removeItem(at: configURL)
        } catch {
            logger.error("Failed to delete data: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw StorageError.fileOperationFailed("Failed to delete data")
        }
    }
}
