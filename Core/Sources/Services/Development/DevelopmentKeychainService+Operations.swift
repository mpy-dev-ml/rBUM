import Foundation
import Security

extension DevelopmentKeychainService {
    // MARK: - Core Operations

    public func save(_ data: Data, for key: String, accessGroup: String?) throws {
        try simulateFailureIfNeeded(
            operation: "save",
            error: KeychainError.saveFailed(status: errSecIO)
        )

        let item = DevelopmentKeychainItem.create(
            data: data,
            accessGroup: accessGroup
        )
        store[key] = item
    }

    public func load(for key: String, accessGroup: String?) throws -> Data {
        try simulateFailureIfNeeded(
            operation: "load",
            error: KeychainError.loadFailed(status: errSecItemNotFound)
        )

        guard let item = store[key], item.accessGroup == accessGroup else {
            throw KeychainError.loadFailed(status: errSecItemNotFound)
        }

        return item.data
    }

    public func delete(for key: String, accessGroup: String?) throws {
        try simulateFailureIfNeeded(
            operation: "delete",
            error: KeychainError.deleteFailed(status: errSecItemNotFound)
        )

        guard let item = store[key], item.accessGroup == accessGroup else {
            throw KeychainError.deleteFailed(status: errSecItemNotFound)
        }

        store.removeValue(forKey: key)
    }

    public func update(_ data: Data, for key: String, accessGroup: String?) throws {
        try simulateFailureIfNeeded(
            operation: "update",
            error: KeychainError.updateFailed(status: errSecItemNotFound)
        )

        guard let item = store[key], item.accessGroup == accessGroup else {
            throw KeychainError.updateFailed(status: errSecItemNotFound)
        }

        let updatedItem = DevelopmentKeychainItem.create(
            data: data,
            accessGroup: accessGroup,
            attributes: item.attributes
        )
        store[key] = updatedItem
    }
}
