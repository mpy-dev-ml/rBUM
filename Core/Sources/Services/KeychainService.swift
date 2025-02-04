import Foundation
import Security

/// Service for managing secure storage in the Keychain
public final class KeychainService: BaseSandboxedService, KeychainServiceProtocol, HealthCheckable {
    public var isHealthy: Bool
    
    public func save(_ data: Data, for key: String, accessGroup: String? = nil) throws {
        try queue.sync {
            var query = baseQuery(for: key, accessGroup: accessGroup)
            query[kSecValueData as String] = data
            
            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecDuplicateItem {
                // Item exists, update it
                let updateQuery = baseQuery(for: key, accessGroup: accessGroup)
                let updateAttributes = [kSecValueData as String: data]
                let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
                
                guard updateStatus == errSecSuccess else {
                    self.logger.error("Failed to update keychain item: \(updateStatus)", file: #file, function: #function, line: #line)
                    throw KeychainError.updateFailed
                }
            } else if status != errSecSuccess {
                self.logger.error("Failed to add keychain item: \(status)", file: #file, function: #function, line: #line)
                throw KeychainError.saveFailed
            }
        }
    }
    
    public func retrieve(for key: String, accessGroup: String? = nil) throws -> Data? {
        try queue.sync {
            var query = baseQuery(for: key, accessGroup: accessGroup)
            query[kSecReturnData as String] = true
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecItemNotFound {
                return nil
            }
            
            guard status == errSecSuccess else {
                self.logger.error("Failed to retrieve keychain item: \(status)", file: #file, function: #function, line: #line)
                throw KeychainError.retrievalFailed
            }
            
            return result as? Data
        }
    }
    
    public func delete(for key: String, accessGroup: String? = nil) throws {
        try queue.sync {
            let query = baseQuery(for: key, accessGroup: accessGroup)
            let status = SecItemDelete(query as CFDictionary)
            
            if status != errSecSuccess && status != errSecItemNotFound {
                self.logger.error("Failed to delete keychain item: \(status)", file: #file, function: #function, line: #line)
                throw KeychainError.deleteFailed
            }
        }
    }
    
    public func configureXPCSharing(accessGroup: String) throws {
        try queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccessGroup as String: accessGroup,
                kSecAttrSynchronizable as String: true
            ]
            
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess && status != errSecDuplicateItem {
                self.logger.error("Failed to configure XPC sharing: \(status)", file: #file, function: #function, line: #line)
                throw KeychainError.xpcConfigurationFailed
            }
            
            self.logger.info("Successfully configured XPC sharing for access group: \(accessGroup)", file: #file, function: #function, line: #line)
        }
    }
    
    public func validateXPCAccess(accessGroup: String) throws -> Bool {
        // No implementation
        return false
    }
    
    // MARK: - Properties
    private let queue: DispatchQueue
    
    // MARK: - Initialization
    public override init(logger: LoggerProtocol, securityService: SecurityServiceProtocol) {
        self.queue = DispatchQueue(label: "dev.mpy.rBUM.keychain", qos: .userInitiated)
        super.init(logger: logger, securityService: securityService)
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Keychain Health Check") {
            do {
                try validateKeychainAccess()
                self.logger.info("Keychain health check passed", file: #file, function: #function, line: #line)
                return true
            } catch {
                self.logger.error("Keychain health check failed: \(error.localizedDescription)", file: #file, function: #function, line: #line)
                return false
            }
        }
    }
    
    // MARK: - Private Helpers
    private func baseQuery(for key: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        
        return query
    }
    
    private func validateKeychainAccess() throws {
        let testKey = "dev.mpy.rBUM.keychain.test"
        let testData = "test".data(using: .utf8)!
        
        do {
            try save(testData, for: testKey)
            try delete(for: testKey)
        } catch {
            throw KeychainError.accessValidationFailed
        }
    }
}
