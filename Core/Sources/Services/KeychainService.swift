import Foundation
import Security

/// Service for managing secure storage in the Keychain
public final class KeychainService: BaseSandboxedService, LoggingService {
    // MARK: - Properties
    private let queue: DispatchQueue
    public private(set) var isHealthy: Bool
    
    // MARK: - Initialization
    public override init(logger: LoggerProtocol, securityService: SecurityServiceProtocol) {
        self.queue = DispatchQueue(label: "dev.mpy.rBUM.keychain", qos: .userInitiated)
        self.isHealthy = true // Default to true, will be updated by health checks
        super.init(logger: logger, securityService: securityService)
    }
    
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
    
    public func retrieve(for key: String, accessGroup: String? = nil) throws -> Data? {
        try queue.sync {
            var query = baseQuery(for: key, accessGroup: accessGroup)
            query[kSecReturnData as String] = true
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            guard status == errSecSuccess else {
                if status == errSecItemNotFound {
                    return nil
                }
                throw KeychainError.retrievalFailed(status: status)
            }
            
            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }
            
            return data
        }
    }
    
    public func delete(for key: String, accessGroup: String? = nil) throws {
        try queue.sync {
            let query = baseQuery(for: key, accessGroup: accessGroup)
            let status = SecItemDelete(query as CFDictionary)
            
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.deletionFailed(status: status)
            }
        }
    }
    
    // MARK: - XPC Configuration
    public func configureXPCSharing(accessGroup: String) throws {
        // Implementation for XPC sharing configuration
        logger.info("Configuring XPC sharing for access group: \(accessGroup)")
        // Add your implementation here
    }
    
    public func validateXPCAccess(accessGroup: String) throws -> Bool {
        // Implementation for XPC access validation
        logger.info("Validating XPC access for group: \(accessGroup)")
        // Add your implementation here
        return true
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Keychain Health Check") {
            do {
                // Try to save and retrieve a test value
                let testKey = "health.check.\(UUID().uuidString)"
                let testData = "test".data(using: .utf8)!
                
                try save(testData, for: testKey)
                let retrieved = try retrieve(for: testKey)
                try delete(for: testKey)
                
                let healthy = retrieved == testData
                isHealthy = healthy
                return healthy
            } catch {
                logger.error("Health check failed: \(error.localizedDescription)")
                isHealthy = false
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
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}

// MARK: - Keychain Errors
public enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case updateFailed(status: OSStatus)
    case retrievalFailed(status: OSStatus)
    case deletionFailed(status: OSStatus)
    case unexpectedData
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to keychain: \(status)"
        case .updateFailed(let status):
            return "Failed to update keychain item: \(status)"
        case .retrievalFailed(let status):
            return "Failed to retrieve from keychain: \(status)"
        case .deletionFailed(let status):
            return "Failed to delete from keychain: \(status)"
        case .unexpectedData:
            return "Unexpected data format in keychain"
        }
    }
}
