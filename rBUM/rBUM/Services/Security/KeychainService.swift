//
//  KeychainService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import Security

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

/// Protocol defining the interface for keychain operations
protocol KeychainServiceProtocol {
    /// Store a password in the keychain
    /// - Parameters:
    ///   - password: The password to store
    ///   - service: The service identifier (e.g., repository ID)
    ///   - account: The account identifier (e.g., repository path)
    func storePassword(_ password: String, forService service: String, account: String) async throws
    
    /// Retrieve a password from the keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    /// - Returns: The stored password
    func retrievePassword(forService service: String, account: String) async throws -> String
    
    /// Update an existing password in the keychain
    /// - Parameters:
    ///   - password: The new password
    ///   - service: The service identifier
    ///   - account: The account identifier
    func updatePassword(_ password: String, forService service: String, account: String) async throws
    
    /// Delete a password from the keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    func deletePassword(forService service: String, account: String) async throws
}

/// Service for managing secure storage of passwords in the macOS Keychain
final class KeychainService: KeychainServiceProtocol {
    private let accessGroup: String?
    private let isTest: Bool
    
    init(accessGroup: String? = nil, isTest: Bool = false) {
        self.accessGroup = accessGroup
        self.isTest = isTest
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
    
    func storePassword(_ password: String, forService service: String, account: String) async throws {
        // First try to delete any existing item
        forceDelete(forService: service, account: account)
        
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        var addQuery = baseQuery(forService: service, account: account)
        addQuery[kSecValueData as String] = passwordData
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        try handleKeychainStatus(status, operation: "store")
    }
    
    func retrievePassword(forService service: String, account: String) async throws -> String {
        var query = baseQuery(forService: service, account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        try handleKeychainStatus(status, operation: "retrieve")
        
        guard let passwordData = result as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainError.unexpectedItemData
        }
        
        return password
    }
    
    func updatePassword(_ password: String, forService service: String, account: String) async throws {
        // First verify the item exists
        if !(try await itemExists(forService: service, account: account)) {
            throw KeychainError.itemNotFound
        }
        
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        let query = baseQuery(forService: service, account: account)
        let attributes: [String: Any] = [kSecValueData as String: passwordData]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        try handleKeychainStatus(status, operation: "update")
    }
    
    func deletePassword(forService service: String, account: String) async throws {
        // First verify the item exists
        if !(try await itemExists(forService: service, account: account)) {
            throw KeychainError.itemNotFound
        }
        
        forceDelete(forService: service, account: account)
    }
}
