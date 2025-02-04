import Foundation
import Security
import Core

/// Service for managing secure storage in the Keychain
public final class KeychainService: BaseSandboxedService, KeychainServiceProtocol, HealthCheckable {
    // MARK: - Properties
    private let serviceName: String
    private let accessGroup: String?
    
    public var isHealthy: Bool {
        // Check if we can access the keychain
        do {
            try validateKeychainAccess()
            return true
        } catch {
            logger.error("Keychain health check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        serviceName: String = "dev.mpy.rBUM",
        accessGroup: String? = nil
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
        super.init(logger: logger, securityService: securityService)
    }
    
    // MARK: - KeychainServiceProtocol Implementation
    public func storeCredentials(_ credentials: KeychainCredentials) throws {
        try measure("Store Credentials") {
            // Convert credentials to data
            let data = try JSONEncoder().encode(credentials)
            
            // Prepare query dictionary
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            
            if let accessGroup = accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }
            
            // Try to add the item
            var status = SecItemAdd(query as CFDictionary, nil)
            
            // If item already exists, update it
            if status == errSecDuplicateItem {
                let searchQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: serviceName
                ]
                
                let updateQuery: [String: Any] = [
                    kSecValueData as String: data
                ]
                
                status = SecItemUpdate(searchQuery as CFDictionary, updateQuery as CFDictionary)
            }
            
            guard status == errSecSuccess else {
                throw KeychainError.saveFailed("Failed to store credentials (status: \(status))")
            }
            
            logger.info("Successfully stored credentials in keychain")
        }
    }
    
    public func retrieveCredentials() throws -> KeychainCredentials {
        try measure("Retrieve Credentials") {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            guard status == errSecSuccess,
                  let data = result as? Data,
                  let credentials = try? JSONDecoder().decode(KeychainCredentials.self, from: data) else {
                throw KeychainError.retrievalFailed("Failed to retrieve credentials (status: \(status))")
            }
            
            logger.info("Successfully retrieved credentials from keychain")
            return credentials
        }
    }
    
    public func deleteCredentials() throws {
        try measure("Delete Credentials") {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.deletionFailed("Failed to delete credentials (status: \(status))")
            }
            
            logger.info("Successfully deleted credentials from keychain")
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Keychain Health Check") {
            do {
                try validateKeychainAccess()
                logger.info("Keychain health check passed")
                return true
            } catch {
                logger.error("Keychain health check failed: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    // MARK: - Private Helpers
    private func validateKeychainAccess() throws {
        // Try to add and then remove a test item
        let testData = "test".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(serviceName).test",
            kSecValueData as String: testData
        ]
        
        // Add test item
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw KeychainError.sandboxViolation("Cannot access keychain")
        }
        
        // Clean up test item
        let deleteStatus = SecItemDelete(query as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainError.sandboxViolation("Cannot clean up keychain test item")
        }
    }
}
