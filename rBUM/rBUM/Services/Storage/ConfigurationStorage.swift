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
    private let fileManager: FileManagerProtocol
    private let notificationCenter: NotificationCenter
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
    
    /// Initialize configuration storage
    /// - Parameters:
    ///   - fileManager: File manager to use for storage
    ///   - notificationCenter: Notification center for change notifications
    ///   - customStorageURL: Optional custom URL for storage location
    init(
        fileManager: FileManagerProtocol = FileManager.default,
        notificationCenter: NotificationCenter = .default,
        customStorageURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.notificationCenter = notificationCenter
        self.customStorageURL = customStorageURL
        try? createStorageDirectoryIfNeeded()
    }
    
    private func createStorageDirectoryIfNeeded() throws {
        let directory = storageURL.deletingLastPathComponent()
        var isDirectory = ObjCBool(false)
        if !fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    func load() throws -> Configuration {
        guard let data = fileManager.contents(atPath: storageURL.path) else {
            return Configuration.default
        }
        return try JSONDecoder().decode(Configuration.self, from: data)
    }
    
    func save(_ configuration: Configuration) throws {
        let data = try JSONEncoder().encode(configuration)
        try fileManager.write(data, to: storageURL)
        notificationCenter.post(name: .configurationDidChange, object: self)
    }
    
    func reset() throws {
        try save(Configuration.default)
    }
}
