import Foundation
import Security
import Core

/// A service for interacting with the macOS Keychain
public final class Keychain {
    private let logger: LoggerProtocol
    private let accessGroup: String?
    private let serviceName: String
    
    /// Initialize a new Keychain service
    /// - Parameters:
    ///   - serviceName: The service name to use for keychain items (default: "dev.mpy.rBUM")
    ///   - accessGroup: Optional access group for sharing keychain items between apps
    ///   - logger: Logger instance for debugging and error reporting
    public init(
        serviceName: String = "dev.mpy.rBUM",
        accessGroup: String? = nil,
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "Keychain")
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
        self.logger = logger
    }
    
    /// Save data to the keychain
    /// - Parameters:
    ///   - data: The data to save
    ///   - account: The account identifier for the data
    public func save(_ data: Data, forAccount account: String) throws {
        // Query to check if item exists
        var query = baseQuery
        query[kSecAttrAccount as String] = account
        
        // Attributes for the item
        var attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        // Try to update existing item
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status == errSecItemNotFound {
            // Item doesn't exist, add it
            query.merge(attributes) { current, _ in current }
            status = SecItemAdd(query as CFDictionary, nil)
        }
        
        guard status == errSecSuccess else {
            logger.error("Failed to save keychain item: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")", file: #file, function: #function, line: #line)
            throw KeychainError.saveFailed(status)
        }
        
        logger.debug("Successfully saved to keychain for account: \(account)", file: #file, function: #function, line: #line)
    }
    
    /// Retrieve data from the keychain
    /// - Parameter account: The account identifier for the data
    /// - Returns: The stored data if found
    public func retrieve(forAccount account: String) throws -> Data {
        var query = baseQuery
        query[kSecAttrAccount as String] = account
        query[kSecReturnData as String] = true
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            logger.error("Failed to retrieve keychain item: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")", file: #file, function: #function, line: #line)
            throw KeychainError.retrieveFailed(status)
        }
        
        logger.debug("Successfully retrieved from keychain for account: \(account)", file: #file, function: #function, line: #line)
        return data
    }
    
    /// Delete data from the keychain
    /// - Parameter account: The account identifier for the data to delete
    public func delete(forAccount account: String) throws {
        var query = baseQuery
        query[kSecAttrAccount as String] = account
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete keychain item: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")", file: #file, function: #function, line: #line)
            throw KeychainError.deleteFailed(status)
        }
        
        logger.debug("Successfully deleted from keychain for account: \(account)", file: #file, function: #function, line: #line)
    }
    
    /// List all accounts in the keychain for this service
    /// - Returns: Array of account identifiers
    public func listAccounts() throws -> [String] {
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        query[kSecReturnAttributes as String] = true
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess || status == errSecItemNotFound,
              let items = result as? [[String: Any]] else {
            if status != errSecItemNotFound {
                logger.error("Failed to list keychain items: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")", file: #file, function: #function, line: #line)
            }
            return []
        }
        
        if status == errSecItemNotFound {
            logger.debug("No items found in keychain", file: #file, function: #function, line: #line)
        }
        
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
    
    // MARK: - Private Helpers
    
    private var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}

/// Errors that can occur during keychain operations
public enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to keychain: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")"
        case .retrieveFailed(let status):
            return "Failed to retrieve from keychain: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")"
        case .deleteFailed(let status):
            return "Failed to delete from keychain: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")"
        }
    }
}
