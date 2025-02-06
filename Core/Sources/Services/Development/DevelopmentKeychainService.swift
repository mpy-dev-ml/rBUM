//
//  DevelopmentKeychainService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation
import Security

/// Development mock implementation of KeychainServiceProtocol
/// Provides simulated keychain behaviour for development
public final class DevelopmentKeychainService: KeychainServiceProtocol {
    // MARK: - Properties
    private let logger: LoggerProtocol
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.developmentKeychain", attributes: .concurrent)
    private var storage: [String: Data] = [:]
    private let configuration: DevelopmentConfiguration
    private var accessGroups: Set<String> = []
    
    // MARK: - Initialization
    public init(logger: LoggerProtocol, configuration: DevelopmentConfiguration = .default) {
        self.logger = logger
        self.configuration = configuration
    }
    
    // MARK: - KeychainServiceProtocol Implementation with Access Groups
    public func save(_ data: Data, for key: String, accessGroup: String?) throws {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating keychain save failure for key: \(key)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.saveFailed(status: errSecIO)
        }
        
        if let group = accessGroup, !accessGroups.contains(group) {
            logger.error(
                "Access group not configured: \(group)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.saveFailed(status: errSecNoAccessForItem)
        }
        
        queue.sync(flags: .barrier) {
            storage[key] = data
            logger.info(
                "Saved data for key: \(key)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    public func retrieve(for key: String, accessGroup: String?) throws -> Data? {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating keychain load failure for key: \(key)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.retrievalFailed(status: errSecItemNotFound)
        }
        
        if let group = accessGroup, !accessGroups.contains(group) {
            logger.error(
                "Access group not configured: \(group)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.retrievalFailed(status: errSecNoAccessForItem)
        }
        
        return try queue.sync {
            guard let data = storage[key] else {
                logger.info(
                    "No data found for key: \(key)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return nil
            }
            
            logger.info(
                "Loaded data for key: \(key)",
                file: #file,
                function: #function,
                line: #line
            )
            return data
        }
    }
    
    public func delete(for key: String, accessGroup: String?) throws {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating keychain delete failure for key: \(key)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.deleteFailed(status: errSecInvalidItemRef)
        }
        
        if let group = accessGroup, !accessGroups.contains(group) {
            logger.error(
                "Access group not configured: \(group)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.deleteFailed(status: errSecNoAccessForItem)
        }
        
        queue.sync(flags: .barrier) {
            storage.removeValue(forKey: key)
            logger.info(
                "Deleted data for key: \(key)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    // MARK: - XPC Access Group Configuration
    public func configureXPCSharing(accessGroup: String) throws {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating XPC sharing configuration failure for group: \(accessGroup)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.xpcConfigurationFailed(status: errSecNoAccessForItem)
        }
        
        queue.sync(flags: .barrier) {
            accessGroups.insert(accessGroup)
            logger.info(
                "Configured XPC sharing for access group: \(accessGroup)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    public func validateXPCAccess(accessGroup: String) throws -> Bool {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating XPC access validation failure for group: \(accessGroup)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.xpcValidationFailed(status: errSecNoAccessForItem)
        }
        
        return queue.sync {
            let isValid = accessGroups.contains(accessGroup)
            logger.info(
                "Validated XPC access for group: \(accessGroup), result: \(isValid)",
                file: #file,
                function: #function,
                line: #line
            )
            return isValid
        }
    }
    
    // MARK: - Legacy Methods (Deprecated)
    @available(*, deprecated, message: "Use save(_:for:accessGroup:) instead")
    public func save(_ data: Data, for key: String) throws {
        try save(data, for: key, accessGroup: nil)
    }
    
    @available(*, deprecated, message: "Use retrieve(for:accessGroup:) instead")
    public func load(for key: String) throws -> Data {
        guard let data = try retrieve(for: key, accessGroup: nil) else {
            throw KeychainError.retrievalFailed(status: errSecItemNotFound)
        }
        return data
    }
    
    @available(*, deprecated, message: "Use delete(for:accessGroup:) instead")
    public func delete(for key: String) throws {
        try delete(for: key, accessGroup: nil)
    }
}
