//
//  DevelopmentKeychainService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Development mock implementation of KeychainServiceProtocol
/// Provides in-memory storage and configurable behaviour for development
public final class DevelopmentKeychainService: KeychainServiceProtocol {
    // MARK: - Properties
    private let logger: LoggerProtocol
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.developmentKeychain", attributes: .concurrent)
    private var storage: [String: Data] = [:]
    
    /// Configuration for simulating keychain behaviour
    public struct Configuration {
        /// Whether to simulate access failures
        public var shouldSimulateAccessFailures: Bool
        /// Whether to simulate storage failures
        public var shouldSimulateStorageFailures: Bool
        /// Whether to simulate XPC failures
        public var shouldSimulateXPCFailures: Bool
        /// Artificial delay for operations (seconds)
        public var artificialDelay: TimeInterval
        
        public init(
            shouldSimulateAccessFailures: Bool = false,
            shouldSimulateStorageFailures: Bool = false,
            shouldSimulateXPCFailures: Bool = false,
            artificialDelay: TimeInterval = 0
        ) {
            self.shouldSimulateAccessFailures = shouldSimulateAccessFailures
            self.shouldSimulateStorageFailures = shouldSimulateStorageFailures
            self.shouldSimulateXPCFailures = shouldSimulateXPCFailures
            self.artificialDelay = artificialDelay
        }
    }
    
    private var configuration: Configuration
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        configuration: Configuration = Configuration()
    ) {
        self.logger = logger
        self.configuration = configuration
        
        logger.info(
            "Initialised DevelopmentKeychainService with configuration: \(String(describing: configuration))",
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    // MARK: - KeychainServiceProtocol Implementation
    public func save(_ data: Data, for key: String, accessGroup: String? = nil) throws {
        if configuration.shouldSimulateStorageFailures {
            logger.error(
                "Simulating storage failure for key: \(key)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.saveFailed(status: errSecDecode)
        }
        
        queue.async(flags: .barrier) {
            self.storage[self.keyWithGroup(key, group: accessGroup)] = data
            self.logger.info(
                "Saved data for key: \(key), group: \(accessGroup ?? "none")",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    public func retrieve(for key: String, accessGroup: String? = nil) throws -> Data? {
        if configuration.shouldSimulateAccessFailures {
            logger.error(
                "Simulating access failure for key: \(key)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.retrievalFailed(status: errSecDecode)
        }
        
        return queue.sync {
            let data = storage[keyWithGroup(key, group: accessGroup)]
            logger.info(
                "Retrieved data for key: \(key), group: \(accessGroup ?? "none")",
                file: #file,
                function: #function,
                line: #line
            )
            return data
        }
    }
    
    public func delete(for key: String, accessGroup: String? = nil) throws {
        if configuration.shouldSimulateStorageFailures {
            logger.error(
                "Simulating deletion failure for key: \(key)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.deletionFailed(status: errSecDecode)
        }
        
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: self.keyWithGroup(key, group: accessGroup))
            self.logger.info(
                "Deleted data for key: \(key), group: \(accessGroup ?? "none")",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    public func configureXPCSharing(accessGroup: String) throws {
        if configuration.shouldSimulateXPCFailures {
            logger.error(
                "Simulating XPC configuration failure for group: \(accessGroup)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.xpcConfigurationFailed
        }
        
        logger.info(
            "Configured XPC sharing for group: \(accessGroup)",
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    public func validateXPCAccess(accessGroup: String) throws -> Bool {
        if configuration.shouldSimulateXPCFailures {
            logger.error(
                "Simulating XPC validation failure for group: \(accessGroup)",
                file: #file,
                function: #function,
                line: #line
            )
            throw KeychainError.xpcValidationFailed
        }
        
        logger.info(
            "Validated XPC access for group: \(accessGroup)",
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    
    // MARK: - Private Helpers
    private func keyWithGroup(_ key: String, group: String?) -> String {
        if let group = group {
            return "\(group).\(key)"
        }
        return key
    }
}
