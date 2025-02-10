import Foundation
import Security

extension KeychainService {
    // MARK: - Query Building

    /// Builds a base keychain query.
    ///
    /// - Parameters:
    ///   - key: The key to build the query for
    ///   - accessGroup: Optional access group for sharing keychain items
    /// - Returns: The base query dictionary
    func baseQuery(for key: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.mpy.rBUM",
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: false,
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}
