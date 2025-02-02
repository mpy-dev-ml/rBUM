//
//  KeychainSecurityServiceTests.swift
//  CoreTests
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Testing
import Foundation
import CryptoKit
@testable import Core

struct KeychainSecurityServiceTests {
    // Use app-group compatible identifiers for testing
    private let testService = "dev.mpy.rBUM.tests"
    private let testIdentifier = "test.credentials"
    
    // Use app group for shared keychain access in sandbox
    private let testAccessGroup = "TEAM_ID.dev.mpy.rBUM.shared"
    
    // Keychain access options for sandbox environment
    private let keychainAccessibility = kSecAttrAccessibleAfterFirstUnlock
    
    @Test
    func testCredentialStorageInSandbox() async throws {
        let service = KeychainSecurityService(
            service: testService,
            accessibility: keychainAccessibility
        )
        
        let testData = "Test credentials".data(using: .utf8)!
        
        // Clean up any existing credentials with error handling
        do {
            try service.deleteCredentials(
                identifier: testIdentifier,
                accessGroup: testAccessGroup
            )
        } catch {
            // Ignore deletion errors during cleanup
            if case SecurityError.credentialsNotFound = error {
                // Expected for first run
            } else {
                throw error
            }
        }
        
        // Test storing credentials with sandbox constraints
        try service.storeCredentials(
            testData,
            identifier: testIdentifier,
            accessGroup: testAccessGroup
        )
        
        // Verify credentials exist
        #expect(service.hasCredentials(
            identifier: testIdentifier,
            accessGroup: testAccessGroup
        ))
        
        // Test retrieving credentials
        let retrieved = try service.retrieveCredentials(
            identifier: testIdentifier,
            accessGroup: testAccessGroup
        )
        #expect(retrieved == testData)
        
        // Clean up
        try service.deleteCredentials(
            identifier: testIdentifier,
            accessGroup: testAccessGroup
        )
    }
    
    @Test
    func testSecureEnclave() async throws {
        let service = KeychainSecurityService(
            service: testService,
            accessibility: keychainAccessibility
        )
        
        // Test Secure Enclave key generation if available
        if service.isSecureEnclaveAvailable {
            let secureKey = try service.generateSecureEnclaveKey(
                tag: "test.key",
                accessControl: [.userPresence]
            )
            #expect(secureKey != nil)
            
            // Clean up
            try service.deleteSecureEnclaveKey(tag: "test.key")
        }
    }
    
    @Test
    func testEncryptionInSandbox() async throws {
        let service = KeychainSecurityService(
            service: testService,
            accessibility: keychainAccessibility
        )
        
        let testString = "Secret message for encryption"
        let testData = testString.data(using: .utf8)!
        
        // Generate encryption key with sandbox-compatible storage
        let key = try service.generateEncryptionKey(
            bits: 256,
            persistKey: true,
            identifier: "test.encryption.key",
            accessGroup: testAccessGroup
        )
        
        #expect(key.count == 32)
        
        // Encrypt data
        let encrypted = try service.encrypt(testData, using: key)
        #expect(encrypted != testData)
        
        // Decrypt data
        let decrypted = try service.decrypt(encrypted, using: key)
        #expect(decrypted == testData)
        
        // Clean up
        try service.deleteEncryptionKey(
            identifier: "test.encryption.key",
            accessGroup: testAccessGroup
        )
    }
    
    @Test
    func testKeyGenerationInSandbox() async throws {
        let service = KeychainSecurityService(
            service: testService,
            accessibility: keychainAccessibility
        )
        
        // Test sandbox-compatible key generation and storage
        let keyIdentifier = "test.key.256"
        let key = try service.generateEncryptionKey(
            bits: 256,
            persistKey: true,
            identifier: keyIdentifier,
            accessGroup: testAccessGroup
        )
        
        #expect(key.count == 32)
        
        // Verify key storage
        let retrievedKey = try service.retrieveEncryptionKey(
            identifier: keyIdentifier,
            accessGroup: testAccessGroup
        )
        
        #expect(retrievedKey == key)
        
        // Clean up
        try service.deleteEncryptionKey(
            identifier: keyIdentifier,
            accessGroup: testAccessGroup
        )
    }
    
    @Test
    func testAccessControlInSandbox() async throws {
        let service = KeychainSecurityService(
            service: testService,
            accessibility: keychainAccessibility
        )
        
        let testData = "Protected data".data(using: .utf8)!
        let identifier = "test.protected.credentials"
        
        // Test storing with access control
        try service.storeCredentials(
            testData,
            identifier: identifier,
            accessGroup: testAccessGroup,
            accessControl: [.userPresence]
        )
        
        // Verify credentials exist
        #expect(service.hasCredentials(
            identifier: identifier,
            accessGroup: testAccessGroup
        ))
        
        // Clean up
        try service.deleteCredentials(
            identifier: identifier,
            accessGroup: testAccessGroup
        )
    }
}

// MARK: - Test Helpers

private extension KeychainSecurityService {
    var isSecureEnclaveAvailable: Bool {
        // Check if device supports Secure Enclave
        #if targetEnvironment(simulator)
            return false
        #else
            return true
        #endif
    }
    
    func generateSecureEnclaveKey(
        tag: String,
        accessControl: SecAccessControlCreateFlags
    ) throws -> SecKey? {
        guard isSecureEnclaveAvailable else { return nil }
        
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            keychainAccessibility,
            accessControl,
            &error
        ) else {
            throw SecurityError.keyGenerationFailed
        }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: access
            ]
        ]
        
        var key: SecKey?
        let status = SecKeyCreateRandomKey(
            attributes as CFDictionary,
            &error
        )
        
        guard status != nil else {
            throw SecurityError.keyGenerationFailed
        }
        
        return status
    }
    
    func deleteSecureEnclaveKey(tag: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecurityError.unknown(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }
}
