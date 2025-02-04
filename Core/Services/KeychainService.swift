import Foundation
import Security

/// Service for managing keychain operations with sandbox compliance and XPC support
public final class KeychainService {
    private let logger: LoggerProtocol
    private let accessGroup: String?
    private let serviceName: String
    private let accessibilityLevel: CFString
    
    /// Initialize the keychain service
    /// - Parameters:
    ///   - serviceName: Name of the service for keychain items
    ///   - accessGroup: Optional access group for XPC sharing
    ///   - accessibilityLevel: Keychain item accessibility level
    ///   - logger: Logger for tracking operations
    public init(
        serviceName: String = "dev.mpy.rBUM",
        accessGroup: String? = nil,
        accessibilityLevel: CFString = kSecAttrAccessibleAfterFirstUnlock,
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "KeychainService")
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
        self.accessibilityLevel = accessibilityLevel
        self.logger = logger
    }
    
    /// Create a query dictionary for keychain operations
    private func createQuery(for key: String, accessGroup: String? = nil) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key,
            kSecAttrAccessible: accessibilityLevel
        ]
        
        // Add access group if specified (required for XPC sharing)
        if let group = accessGroup ?? self.accessGroup {
            query[kSecAttrAccessGroup] = group
        }
        
        return query
    }
    
    /// Handle keychain operation result
    private func handleKeychainError(_ status: OSStatus, operation: String, file: String = #file, function: String = #function, line: Int = #line) throws {
        guard status != errSecSuccess else { return }
        
        let message: String
        switch status {
        case errSecDuplicateItem:
            throw KeychainError.duplicateItem("Item already exists")
        case errSecItemNotFound:
            throw KeychainError.retrievalFailed("Item not found")
        case errSecAuthFailed:
            message = "Authentication failed"
            throw KeychainError.sandboxViolation(message)
        case errSecNoAccessForItem:
            message = "No access to item"
            throw KeychainError.sandboxViolation(message)
        default:
            message = "Keychain operation failed with status: \(status)"
            throw KeychainError.saveFailed(message)
        }
    }
}

// MARK: - KeychainServiceProtocol Implementation

extension KeychainService: KeychainServiceProtocol {
    public func save(_ data: Data, for key: String, accessGroup: String?) throws {
        logger.debug("Saving keychain item for key: \(key)", file: #file, function: #function, line: #line)
        
        var query = createQuery(for: key, accessGroup: accessGroup)
        query[kSecValueData] = data
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // Item exists, update it
            let updateQuery = createQuery(for: key, accessGroup: accessGroup)
            let updateAttributes: [CFString: Any] = [kSecValueData: data]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            try handleKeychainError(updateStatus, operation: "update")
            
            logger.info("Updated existing keychain item for key: \(key)", file: #file, function: #function, line: #line)
        } else {
            try handleKeychainError(status, operation: "save")
            logger.info("Saved new keychain item for key: \(key)", file: #file, function: #function, line: #line)
        }
    }
    
    public func retrieve(for key: String, accessGroup: String?) throws -> Data? {
        logger.debug("Retrieving keychain item for key: \(key)", file: #file, function: #function, line: #line)
        
        var query = createQuery(for: key, accessGroup: accessGroup)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            logger.debug("No keychain item found for key: \(key)", file: #file, function: #function, line: #line)
            return nil
        }
        
        try handleKeychainError(status, operation: "retrieve")
        
        guard let data = result as? Data else {
            logger.error("Retrieved item is not Data for key: \(key)", file: #file, function: #function, line: #line)
            throw KeychainError.invalidData("Retrieved item is not Data")
        }
        
        logger.info("Successfully retrieved keychain item for key: \(key)", file: #file, function: #function, line: #line)
        return data
    }
    
    public func delete(for key: String, accessGroup: String?) throws {
        logger.debug("Deleting keychain item for key: \(key)", file: #file, function: #function, line: #line)
        
        let query = createQuery(for: key, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecItemNotFound {
            try handleKeychainError(status, operation: "delete")
        }
        
        logger.info("Deleted keychain item for key: \(key)", file: #file, function: #function, line: #line)
    }
    
    public func configureXPCSharing(accessGroup: String) throws {
        logger.debug("Configuring XPC sharing with access group: \(accessGroup)", file: #file, function: #function, line: #line)
        
        guard !accessGroup.isEmpty else {
            logger.error("Invalid access group provided", file: #file, function: #function, line: #line)
            throw KeychainError.invalidData("Access group cannot be empty")
        }
        
        // Verify access group format
        guard accessGroup.hasPrefix("dev.mpy.rBUM.") else {
            logger.error("Invalid access group format", file: #file, function: #function, line: #line)
            throw KeychainError.invalidData("Access group must start with app identifier prefix")
        }
        
        // Test access group by attempting to save and retrieve a test item
        let testKey = "xpc.test.\(UUID().uuidString)"
        let testData = "test".data(using: .utf8)!
        
        do {
            try save(testData, for: testKey, accessGroup: accessGroup)
            let retrieved = try retrieve(for: testKey, accessGroup: accessGroup)
            try delete(for: testKey, accessGroup: accessGroup)
            
            guard retrieved == testData else {
                throw KeychainError.invalidData("Test data verification failed")
            }
            
            logger.info("Successfully configured XPC sharing with access group: \(accessGroup)", file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to configure XPC sharing: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw KeychainError.sandboxViolation("Failed to configure XPC sharing: \(error.localizedDescription)")
        }
    }
    
    public func validateXPCAccess(accessGroup: String) throws -> Bool {
        logger.debug("Validating XPC access for group: \(accessGroup)", file: #file, function: #function, line: #line)
        
        let testKey = "xpc.validation.\(UUID().uuidString)"
        let testData = "validation".data(using: .utf8)!
        
        do {
            try save(testData, for: testKey, accessGroup: accessGroup)
            let retrieved = try retrieve(for: testKey, accessGroup: accessGroup)
            try delete(for: testKey, accessGroup: accessGroup)
            
            let isValid = retrieved == testData
            logger.info("XPC access validation \(isValid ? "succeeded" : "failed") for group: \(accessGroup)", file: #file, function: #function, line: #line)
            return isValid
            
        } catch {
            logger.error("XPC access validation failed: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw KeychainError.sandboxViolation("XPC access validation failed: \(error.localizedDescription)")
        }
    }
}
