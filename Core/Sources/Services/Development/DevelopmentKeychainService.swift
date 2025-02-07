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
    // MARK: - Types

    /// Represents a keychain item with metadata
    private struct KeychainItem {
        let data: Data
        let createdAt: Date
        let lastAccessed: Date
        let accessCount: Int
        let accessGroup: String?
        let attributes: [String: Any]

        static func create(
            data: Data,
            accessGroup: String?,
            attributes: [String: Any] = [:]
        ) -> KeychainItem {
            let now = Date()
            return KeychainItem(
                data: data,
                createdAt: now,
                lastAccessed: now,
                accessCount: 0,
                accessGroup: accessGroup,
                attributes: attributes
            )
        }

        func accessed() -> KeychainItem {
            KeychainItem(
                data: data,
                createdAt: createdAt,
                lastAccessed: Date(),
                accessCount: accessCount + 1,
                accessGroup: accessGroup,
                attributes: attributes
            )
        }
    }

    /// Tracks metrics for keychain operations
    private struct KeychainMetrics {
        private(set) var saveCount: Int = 0
        private(set) var retrievalCount: Int = 0
        private(set) var deleteCount: Int = 0
        private(set) var failureCount: Int = 0
        private(set) var accessGroupConfigCount: Int = 0
        private(set) var accessValidationCount: Int = 0

        mutating func recordSave() {
            saveCount += 1
        }

        mutating func recordRetrieval() {
            retrievalCount += 1
        }

        mutating func recordDelete() {
            deleteCount += 1
        }

        mutating func recordFailure(operation _: String) {
            failureCount += 1
        }

        mutating func recordAccessGroupConfig() {
            accessGroupConfigCount += 1
        }

        mutating func recordAccessValidation() {
            accessValidationCount += 1
        }
    }

    // MARK: - Properties

    private let logger: LoggerProtocol
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.developmentKeychain", attributes: .concurrent)
    private var storage: [String: KeychainItem] = [:]
    private let configuration: DevelopmentConfiguration
    private var accessGroups: Set<String> = []
    private var metrics = KeychainMetrics()

    // MARK: - Initialization

    public init(logger: LoggerProtocol, configuration: DevelopmentConfiguration = .default) {
        self.logger = logger
        self.configuration = configuration

        logger.info(
            """
            Initialised DevelopmentKeychainService with configuration:
            \(String(describing: configuration))
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }

    // MARK: - Private Methods

    /// Validate access group permissions
    private func validateAccessGroup(_ group: String?) throws {
        guard let group else { return }

        if !accessGroups.contains(group) {
            logger.error(
                "Access group not configured: \(group)",
                file: #file,
                function: #function,
                line: #line
            )
            metrics.recordFailure(operation: "access_group_validation")
            throw KeychainError.noAccessForItem(group: group)
        }
    }

    /// Simulate failure if configured
    private func simulateFailureIfNeeded(
        operation: String,
        error: Error
    ) throws {
        guard configuration.shouldSimulateAccessFailures else { return }

        logger.error(
            "Simulating keychain \(operation) failure",
            file: #file,
            function: #function,
            line: #line
        )
        metrics.recordFailure(operation: operation)
        throw error
    }

    // MARK: - KeychainServiceProtocol Implementation with Access Groups

    public func save(_ data: Data, for key: String, accessGroup: String?) throws {
        try simulateFailureIfNeeded(
            operation: "save",
            error: KeychainError.saveFailed(status: errSecIO)
        )

        try validateAccessGroup(accessGroup)

        queue.sync(flags: .barrier) {
            let item = KeychainItem.create(
                data: data,
                accessGroup: accessGroup,
                attributes: [
                    "creation_date": Date(),
                    "last_modified": Date(),
                    "accessible": true,
                    "access_control": accessGroup != nil,
                ]
            )
            storage[key] = item
            metrics.recordSave()

            logger.info(
                """
                Saved data for key: \(key)
                Access Group: \(accessGroup ?? "none")
                """,
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    public func retrieve(for key: String, accessGroup: String?) throws -> Data? {
        try simulateFailureIfNeeded(
            operation: "retrieve",
            error: KeychainError.retrievalFailed(status: errSecItemNotFound)
        )

        try validateAccessGroup(accessGroup)

        return try queue.sync {
            guard var item = storage[key] else {
                logger.info(
                    """
                    No data found for key: \(key)
                    Access Group: \(accessGroup ?? "none")
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                return nil
            }

            // Validate access group matches
            if let requiredGroup = accessGroup,
               item.accessGroup != requiredGroup
            {
                logger.error(
                    """
                    Access group mismatch:
                    Required: \(requiredGroup)
                    Actual: \(item.accessGroup ?? "none")
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                metrics.recordFailure(operation: "access_group_mismatch")
                throw KeychainError.noAccessForItem(group: requiredGroup)
            }

            // Update access metrics
            item = item.accessed()
            storage[key] = item
            metrics.recordRetrieval()

            logger.info(
                """
                Retrieved data for key: \(key)
                Access Group: \(accessGroup ?? "none")
                Access Count: \(item.accessCount)
                """,
                file: #file,
                function: #function,
                line: #line
            )

            return item.data
        }
    }

    public func delete(for key: String, accessGroup: String?) throws {
        try simulateFailureIfNeeded(
            operation: "delete",
            error: KeychainError.deleteFailed(status: errSecInvalidItemRef)
        )

        try validateAccessGroup(accessGroup)

        queue.sync(flags: .barrier) {
            guard let item = storage[key] else {
                logger.info(
                    """
                    No data found to delete for key: \(key)
                    Access Group: \(accessGroup ?? "none")
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                return
            }

            // Validate access group matches
            if let requiredGroup = accessGroup,
               item.accessGroup != requiredGroup
            {
                logger.error(
                    """
                    Access group mismatch for deletion:
                    Required: \(requiredGroup)
                    Actual: \(item.accessGroup ?? "none")
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                return
            }

            storage.removeValue(forKey: key)
            metrics.recordDelete()

            logger.info(
                """
                Deleted data for key: \(key)
                Access Group: \(accessGroup ?? "none")
                """,
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    // MARK: - XPC Access Group Configuration

    public func configureXPCSharing(accessGroup: String) throws {
        try simulateFailureIfNeeded(
            operation: "xpc_config",
            error: KeychainError.xpcConfigurationFailed
        )

        queue.sync(flags: .barrier) {
            accessGroups.insert(accessGroup)
            metrics.recordAccessGroupConfig()

            logger.info(
                """
                Configured XPC sharing for access group: \(accessGroup)
                Total Access Groups: \(accessGroups.count)
                """,
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    public func validateXPCAccess(accessGroup: String) throws -> Bool {
        try simulateFailureIfNeeded(
            operation: "xpc_validation",
            error: KeychainError.accessValidationFailed
        )

        return queue.sync {
            let isValid = accessGroups.contains(accessGroup)
            metrics.recordAccessValidation()

            logger.info(
                """
                Validated XPC access for group: \(accessGroup)
                Result: \(isValid)
                Total Access Groups: \(accessGroups.count)
                """,
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
