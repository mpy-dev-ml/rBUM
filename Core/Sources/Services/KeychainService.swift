//
//  KeychainService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation
import Security

/// Service for managing secure storage in the Keychain
public final class KeychainService: BaseSandboxedService, Measurable {
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
    
    public func delete(for key: String, accessGroup: String? = nil) throws {
        try queue.sync {
            let query = baseQuery(for: key, accessGroup: accessGroup)
            let status = SecItemDelete(query as CFDictionary)
            
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.deleteFailed(status: status)
            }
        }
    }
    
    // MARK: - Health Check
    public func performHealthCheck() async -> Bool {
        logger.info("Performing keychain health check",
                   file: #file,
                   function: #function,
                   line: #line)
        
        do {
            let testKey = "health_check"
            let string = "test"
            let data = Data(string.utf8)
            
            try save(data, for: testKey)
            try delete(for: testKey)
            
            logger.info("Keychain health check passed",
                       file: #file,
                       function: #function,
                       line: #line)
            return true
        } catch {
            logger.error("Keychain health check failed: \(error.localizedDescription)",
                        file: #file,
                        function: #function,
                        line: #line)
            return false
        }
    }
    
    // MARK: - Private Methods
    private func baseQuery(for key: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.mpy.rBUM",
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: false
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}
