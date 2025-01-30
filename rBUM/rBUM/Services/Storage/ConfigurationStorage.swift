//
//  ConfigurationStorage.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Protocol for managing configuration storage
protocol ConfigurationStorageProtocol {
    /// Load the current configuration
    /// - Returns: The current configuration
    func load() throws -> Configuration
    
    /// Save the configuration
    /// - Parameter configuration: The configuration to save
    func save(_ configuration: Configuration) throws
    
    /// Reset configuration to default values
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

/// Manages the storage of application configuration using FileManager
final class ConfigurationStorage: ConfigurationStorageProtocol {
    private let fileManager: FileManager
    private let logger = Logging.logger(for: .configuration)
    private let customStorageURL: URL?
    
    /// URL where configuration is stored
    private var storageURL: URL {
        if let customURL = customStorageURL {
            return customURL
        }
        
        let appSupport = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent("dev.mpy.rBUM", isDirectory: true)
            .appendingPathComponent("config.json")
    }
    
    init(fileManager: FileManager = .default, storageURL: URL? = nil) {
        self.fileManager = fileManager
        self.customStorageURL = storageURL
        try? createStorageDirectoryIfNeeded()
    }
    
    private func createStorageDirectoryIfNeeded() throws {
        let directory = storageURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    func load() throws -> Configuration {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            // If no configuration exists, create default
            let config = Configuration.default
            try save(config)
            return config
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            return try decoder.decode(Configuration.self, from: data)
        } catch {
            logger.errorMessage("Failed to load configuration: \(error.localizedDescription)")
            throw ConfigurationStorageError.fileOperationFailed("read")
        }
    }
    
    func save(_ configuration: Configuration) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(configuration)
            try data.write(to: storageURL, options: .atomic)
            logger.infoMessage("Saved configuration")
        } catch {
            logger.errorMessage("Failed to save configuration: \(error.localizedDescription)")
            throw ConfigurationStorageError.fileOperationFailed("write")
        }
    }
    
    func reset() throws {
        try save(Configuration.default)
        logger.infoMessage("Reset configuration to defaults")
    }
}
