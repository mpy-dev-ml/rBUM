import Foundation
import Security

extension KeychainService {
    // MARK: - Operations
    
    /// Saves data to the keychain.
    ///
    /// - Parameters:
    ///   - data: The data to save
    ///   - key: The key to save the data under
    ///   - accessGroup: Optional access group for sharing keychain items
    /// - Throws: KeychainError if save fails
    public func save(_ data: Data, for key: String, accessGroup: String? = nil) throws {
        try queue.sync {
            var query = baseQuery(for: key, accessGroup: accessGroup)
            query[kSecValueData as String] = data

            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecDuplicateItem {
                // Item exists, update it
                let updateQuery = baseQuery(for: key, accessGroup: accessGroup)
                let updateAttributes = [kSecValueData as String: data] as CFDictionary

                let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes)
                guard updateStatus == errSecSuccess else {
                    throw KeychainError.updateFailed(status: updateStatus)
                }
            } else if status != errSecSuccess {
                throw KeychainError.saveFailed(status: status)
            }
        }
    }

    /// Retrieves data from the keychain.
    ///
    /// - Parameters:
    ///   - key: The key to retrieve data for
    ///   - accessGroup: Optional access group for sharing keychain items
    /// - Returns: The retrieved data, or nil if not found
    /// - Throws: KeychainError if retrieval fails
    public func retrieve(for key: String, accessGroup: String? = nil) throws -> Data? {
        try queue.sync {
            var query = baseQuery(for: key, accessGroup: accessGroup)
            query[kSecReturnData as String] = true

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            guard status == errSecSuccess else {
                if status == errSecItemNotFound {
                    return Data()
                }
                throw KeychainError.retrievalFailed(status: status)
            }

            guard let data = result as? Data else {
                throw KeychainError.retrievalFailed(status: errSecDecode)
            }

            return data
        }
    }

    /// Deletes data from the keychain.
    ///
    /// - Parameters:
    ///   - key: The key to delete data for
    ///   - accessGroup: Optional access group for sharing keychain items
    /// - Throws: KeychainError if deletion fails
    public func delete(for key: String, accessGroup: String? = nil) throws {
        try queue.sync {
            let query = baseQuery(for: key, accessGroup: accessGroup)
            let status = SecItemDelete(query as CFDictionary)

            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.deleteFailed(status: status)
            }
        }
    }
}
