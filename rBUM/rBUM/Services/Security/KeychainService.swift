//
//  KeychainService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Security
import os

/// Errors that can occur during Keychain operations
enum KeychainError: LocalizedError, Equatable {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case dataConversionError
    case unexpectedItemData
    
    static func == (lhs: KeychainError, rhs: KeychainError) -> Bool {
        switch (lhs, rhs) {
        case (.duplicateItem, .duplicateItem):
            return true
        case (.itemNotFound, .itemNotFound):
            return true
        case (.unexpectedStatus(let lhsStatus), .unexpectedStatus(let rhsStatus)):
            return lhsStatus == rhsStatus
        case (.dataConversionError, .dataConversionError):
            return true
        case (.unexpectedItemData, .unexpectedItemData):
            return true
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "A credential for this item already exists"
        case .itemNotFound:
            return "The requested item could not be found in the keychain"
        case .unexpectedStatus(let status):
            return "Keychain operation failed: \(status)"
        case .dataConversionError:
            return "Failed to convert data to/from the keychain"
        case .unexpectedItemData:
            return "Unexpected data format in keychain item"
        }
    }
}

/// Protocol for secure storage in macOS Keychain
protocol KeychainServiceProtocol {
    /// Store data in Keychain
    func store(_ data: Data, service: String, account: String) async throws
    
    /// Retrieve data from Keychain
    func retrieve(service: String, account: String) async throws -> Data
    
    /// Update existing data in Keychain
    func update(_ data: Data, service: String, account: String) async throws
    
    /// Delete data from Keychain
    func delete(service: String, account: String) async throws
    
    /// Store a password in the keychain
    func storePassword(_ password: String, service: String, account: String) async throws
    
    /// Retrieve a password from the keychain
    func retrievePassword(service: String, account: String) async throws -> String
    
    /// Update a password in the keychain
    func updatePassword(_ password: String, service: String, account: String) async throws
    
    /// Delete a password from the keychain
    func deletePassword(service: String, account: String) async throws
}

/// Manages secure storage using macOS Keychain
final class KeychainService: KeychainServiceProtocol {
    private let logger: Logger
    private let accessGroup: String?  // Optional Keychain access group
    private let isTest: Bool          // Test mode flag
    
    init(accessGroup: String? = nil, isTest: Bool = false) {
        self.accessGroup = accessGroup
        self.isTest = isTest
        self.logger = Logging.logger(for: .keychain)
    }
    
    func update(_ data: Data, service: String, account: String) async throws {
        logger.debug("Updating keychain item for service: \(service, privacy: .public)")
        
        // First verify the item exists
        if !(try await itemExists(forService: service, account: account)) {
            logger.error("Item not found for service: \(service, privacy: .public)")
            throw KeychainError.itemNotFound
        }
        
        let query = baseQuery(forService: service, account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        try handleKeychainStatus(status, operation: "update")
        
        logger.debug("Successfully updated keychain item for service: \(service, privacy: .public)")
    }
    
    func delete(service: String, account: String) async throws {
        logger.debug("Deleting keychain item for service: \(service, privacy: .public)")
        
        // First verify the item exists
        if !(try await itemExists(forService: service, account: account)) {
            logger.error("Item not found for service: \(service, privacy: .public)")
            throw KeychainError.itemNotFound
        }
        
        forceDelete(forService: service, account: account)
        logger.debug("Successfully deleted keychain item for service: \(service, privacy: .public)")
    }
    
    private func baseQuery(forService service: String, account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // For tests, use a more permissive accessibility setting that's still secure
        if isTest {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        }
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
    
    private func handleKeychainStatus(_ status: OSStatus, operation: String) throws {
        switch status {
        case errSecSuccess, 0:
            return
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        case errSecDuplicateItem:
            throw KeychainError.duplicateItem
        case errSecNotAvailable, errSecParam:
            // These errors often indicate the keychain is not properly initialized
            // or the parameters are invalid. Map them to itemNotFound for our use case.
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    private func itemExists(forService service: String, account: String) async throws -> Bool {
        var query = baseQuery(forService: service, account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess || status == 0 {
            return true
        }
        if status == errSecItemNotFound || status == errSecNotAvailable || status == errSecParam {
            return false
        }
        throw KeychainError.unexpectedStatus(status)
    }
    
    private func forceDelete(forService service: String, account: String) {
        let query = baseQuery(forService: service, account: account)
        _ = SecItemDelete(query as CFDictionary)
    }
    
    func store(_ data: Data, service: String, account: String) async throws {
        logger.debug("Storing keychain item for service: \(service, privacy: .public)")
        
        // First try to delete any existing item
        forceDelete(forService: service, account: account)
        
        var addQuery = baseQuery(forService: service, account: account)
        addQuery[kSecValueData as String] = data
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        try handleKeychainStatus(status, operation: "store")
        
        logger.debug("Successfully stored keychain item for service: \(service, privacy: .public)")
    }
    
    func retrieve(service: String, account: String) async throws -> Data {
        logger.debug("Retrieving keychain item for service: \(service, privacy: .public)")
        
        var query = baseQuery(forService: service, account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        try handleKeychainStatus(status, operation: "retrieve")
        
        guard let data = result as? Data else {
            throw KeychainError.unexpectedItemData
        }
        
        logger.debug("Successfully retrieved keychain item for service: \(service, privacy: .public)")
        return data
    }
    
    func storePassword(_ password: String, service: String, account: String) async throws {
        logger.debug("Storing password in keychain for service: \(service, privacy: .public)")
        
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        // Keychain operations can be slow, so we run them in a background task
        return try await Task.detached(priority: .userInitiated) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data
            ]
            
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                if status == errSecDuplicateItem {
                    throw KeychainError.duplicateItem
                }
                throw KeychainError.unexpectedStatus(status)
            }
            self.logger.debug("Successfully stored password in keychain for service: \(service, privacy: .public)")
        }.value
    }
    
    func retrievePassword(service: String, account: String) async throws -> String {
        logger.debug("Retrieving password from keychain for service: \(service, privacy: .public)")
        
        // Keychain operations can be slow, so we run them in a background task
        return try await Task.detached(priority: .userInitiated) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecReturnData as String: true
            ]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess else {
                if status == errSecItemNotFound {
                    throw KeychainError.itemNotFound
                }
                throw KeychainError.unexpectedStatus(status)
            }
            
            guard let data = item as? Data,
                  let password = String(data: data, encoding: .utf8) else {
                throw KeychainError.dataConversionError
            }
            
            self.logger.debug("Successfully retrieved password from keychain for service: \(service, privacy: .public)")
            return password
        }.value
    }
    
    func updatePassword(_ password: String, service: String, account: String) async throws {
        logger.debug("Updating password in keychain for service: \(service, privacy: .public)")
        
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        // Keychain operations can be slow, so we run them in a background task
        return try await Task.detached(priority: .userInitiated) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                if status == errSecItemNotFound {
                    throw KeychainError.itemNotFound
                }
                throw KeychainError.unexpectedStatus(status)
            }
            self.logger.debug("Successfully updated password in keychain for service: \(service, privacy: .public)")
        }.value
    }
    
    func deletePassword(service: String, account: String) async throws {
        logger.debug("Deleting password from keychain for service: \(service, privacy: .public)")
        
        // Keychain operations can be slow, so we run them in a background task
        return try await Task.detached(priority: .userInitiated) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess else {
                if status == errSecItemNotFound {
                    throw KeychainError.itemNotFound
                }
                throw KeychainError.unexpectedStatus(status)
            }
            self.logger.debug("Successfully deleted password from keychain for service: \(service, privacy: .public)")
        }.value
    }
}
