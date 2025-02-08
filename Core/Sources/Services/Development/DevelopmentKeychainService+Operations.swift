import Foundation
import Security

extension DevelopmentKeychainService {
    // MARK: - Core Operations

    /// Saves data to the development keychain for the specified key.
    ///
    /// - Parameters:
    ///   - data: The data to save in the keychain
    ///   - key: The key to associate with the data
    ///   - accessGroup: Optional access group for sharing keychain items
    /// - Throws: `KeychainError` if the save operation fails
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

    /// Loads data from the development keychain for the specified key.
    ///
    /// - Parameters:
    ///   - key: The key associated with the data
    ///   - accessGroup: Optional access group for sharing keychain items
    /// - Returns: The data stored in the keychain
    /// - Throws: `KeychainError` if the load operation fails or the item is not found
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

    /// Deletes data from the development keychain for the specified key.
    ///
    /// - Parameters:
    ///   - key: The key associated with the data
    ///   - accessGroup: Optional access group for sharing keychain items
    /// - Throws: `KeychainError` if the delete operation fails or the item is not found
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

    /// Updates data in the development keychain for the specified key.
    ///
    /// - Parameters:
    ///   - data: The new data to store in the keychain
    ///   - key: The key associated with the data
    ///   - accessGroup: Optional access group for sharing keychain items
    /// - Throws: `KeychainError` if the update operation fails or the item is not found
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
