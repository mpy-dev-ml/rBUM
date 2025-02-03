//
//  ConfigurationStorage.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Core

/// Protocol for managing configuration storage
public protocol ConfigurationStorageProtocol {
    /// Load the current configuration
    /// - Returns: The current configuration
    /// - Throws: ConfigurationError if loading fails
    func load() throws -> Configuration
    
    /// Save the configuration
    /// - Parameter configuration: The configuration to save
    /// - Throws: ConfigurationError if saving fails
    func save(_ configuration: Configuration) throws
    
    /// Reset configuration to default values
    /// - Throws: ConfigurationError if reset fails
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

/// FileSystem-based implementation of ConfigurationStorageProtocol
public final class ConfigurationStorage: ConfigurationStorageProtocol {
    // MARK: - Properties
    
    private let fileManager: FileManagerProtocol
    private let logger: LoggerProtocol
    private let configURL: URL
    
    // MARK: - Initialization
    
    /// Initialises a new ConfigurationStorage instance
    /// - Parameters:
    ///   - fileManager: FileManager to use for file operations
    ///   - logger: Logger for recording operations
    /// - Throws: ConfigurationError if setup fails
    public init(
        fileManager: FileManagerProtocol = DefaultFileManager(),
        logger: LoggerProtocol = Logging.logger(for: .configuration)
    ) throws {
        self.fileManager = fileManager
        self.logger = logger
        
        // Get application support directory
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Could not access application support directory", privacy: .public, file: #file, function: #function, line: #line)
            throw ConfigurationError.accessDenied
        }
        
        // Create config directory if needed
        let configDir = appSupport.appendingPathComponent("Configuration", isDirectory: true)
        if !fileManager.directoryExists(atPath: configDir.path) {
            do {
                try fileManager.createDirectory(
                    atPath: configDir.path,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                logger.error("Failed to create configuration directory: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
                throw ConfigurationError.saveFailed("Could not create configuration directory")
            }
        }
        
        self.configURL = configDir.appendingPathComponent("config.json")
        logger.debug("Configuration file path: \(configURL.path)", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    // MARK: - ConfigurationStorageProtocol Implementation
    
    public func load() throws -> Configuration {
        logger.debug("Loading configuration", privacy: .public, file: #file, function: #function, line: #line)
        
        if !fileManager.fileExists(atPath: configURL.path) {
            logger.info("Configuration file not found, using defaults", privacy: .public, file: #file, function: #function, line: #line)
            return .default
        }
        
        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            let config = try decoder.decode(Configuration.self, from: data)
            logger.info("Successfully loaded configuration", privacy: .public, file: #file, function: #function, line: #line)
            return config
        } catch {
            logger.error("Failed to load configuration: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw ConfigurationError.loadFailed(error.localizedDescription)
        }
    }
    
    public func save(_ configuration: Configuration) throws {
        logger.debug("Saving configuration", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(configuration)
            try data.write(to: configURL, options: .atomic)
            logger.info("Successfully saved configuration", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to save configuration: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw ConfigurationError.saveFailed(error.localizedDescription)
        }
    }
    
    public func reset() throws {
        logger.debug("Resetting configuration", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            if fileManager.fileExists(atPath: configURL.path) {
                try fileManager.removeItem(atPath: configURL.path)
            }
            try save(.default)
            logger.info("Successfully reset configuration", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to reset configuration: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw ConfigurationError.resetFailed(error.localizedDescription)
        }
    }
}
