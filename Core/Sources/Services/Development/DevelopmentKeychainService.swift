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

    /// In-memory storage for keychain items
    private var store: [String: DevelopmentKeychainItem] = [:]

    /// Simulated failure rates for different operations
    private var simulatedFailureRates: [String: Double] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - XPC Configuration

    public func configureXPCSharing(accessGroup: String) throws {
        try simulateFailureIfNeeded(
            operation: "xpc_config",
            error: KeychainError.xpcConfigurationFailed
        )
    }
}

// MARK: - KeychainServiceProtocol Implementation

extension DevelopmentKeychainService {
    public func save(_ data: Data, for key: String, accessGroup: String?) throws {
        try simulateFailureIfNeeded(
            operation: "save",
            error: KeychainError.saveFailed(status: errSecIO)
        )

        try validateAccessGroup(accessGroup)

        queue.sync(flags: .barrier) {
            let item = DevelopmentKeychainItem.create(
                data: data,
                accessGroup: accessGroup,
                attributes: [
                    "creation_date": Date(),
                    "last_modified": Date(),
                    "accessible": true,
                    "access_control": accessGroup != nil
                ]
            )
            store[key] = item
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
            guard var item = store[key] else {
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
               item.accessGroup != requiredGroup {
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
            store[key] = item
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
            guard let item = store[key] else {
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
               item.accessGroup != requiredGroup {
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

            store.removeValue(forKey: key)
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
}

// MARK: - Private Methods

extension DevelopmentKeychainService {
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
}

// MARK: - Legacy Methods (Deprecated)

extension DevelopmentKeychainService {
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
