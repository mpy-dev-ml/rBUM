//
//  KeychainSecurityService.swift
//  Core
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation
import Security
import CryptoKit
import LocalAuthentication

/// A macOS implementation of SecurityServiceProtocol using Keychain Services and CryptoKit
public final class KeychainSecurityService: SecurityServiceProtocol {
    /// Service identifier for keychain items
    private let service: String
    
    /// Keychain accessibility setting
    private let accessibility: CFString
    
    /// Authentication context for biometric and password operations
    private let authContext: LAContext
    
    /// Creates a new KeychainSecurityService instance
    /// - Parameters:
    ///   - service: Service identifier for keychain items
    ///   - accessibility: Keychain accessibility setting
    ///   - authContext: Authentication context for biometric operations
    public init(
        service: String = "dev.mpy.rBUM",
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlock,
        authContext: LAContext = LAContext()
    ) {
        self.service = service
        self.accessibility = accessibility
        self.authContext = authContext
    }
    
    public func storeCredentials(
        _ credentials: Data,
        identifier: String,
        accessGroup: String?,
        accessControl: SecAccessControlCreateFlags = []
    ) throws {
        var query = baseQuery(identifier: identifier, accessGroup: accessGroup)
        
        // Check if credentials already exist
        if hasCredentials(identifier: identifier, accessGroup: accessGroup) {
            throw SecurityError.credentialsExists
        }
        
        // Set up access control if specified
        if !accessControl.isEmpty {
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                accessibility,
                accessControl,
                &error
            ) else {
                throw SecurityError.accessDenied
            }
            query[kSecAttrAccessControl as String] = access
        } else {
            query[kSecAttrAccessible as String] = accessibility
        }
        
        query[kSecValueData as String] = credentials
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw convertError(status)
        }
    }
    
    public func retrieveCredentials(
        identifier: String,
        accessGroup: String?
    ) throws -> Data {
        var query = baseQuery(identifier: identifier, accessGroup: accessGroup)
        query[kSecReturnData as String] = true
        query[kSecUseOperationPrompt as String] = "Access secure credential"
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw convertError(status)
        }
        
        return data
    }
    
    public func deleteCredentials(
        identifier: String,
        accessGroup: String?
    ) throws {
        let query = baseQuery(identifier: identifier, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw convertError(status)
        }
    }
    
    public func updateCredentials(
        _ credentials: Data,
        identifier: String,
        accessGroup: String?
    ) throws {
        let query = baseQuery(identifier: identifier, accessGroup: accessGroup)
        let attributes = [kSecValueData as String: credentials]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw convertError(status)
        }
    }
    
    public func hasCredentials(
        identifier: String,
        accessGroup: String?
    ) -> Bool {
        var query = baseQuery(identifier: identifier, accessGroup: accessGroup)
        query[kSecReturnData as String] = false
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func generateEncryptionKey(
        bits: Int,
        persistKey: Bool = false,
        identifier: String? = nil,
        accessGroup: String? = nil
    ) throws -> Data {
        guard bits == 128 || bits == 256 else {
            throw SecurityError.keyGenerationFailed
        }
        
        let keySize = bits / 8
        var keyData = Data(count: keySize)
        
        let result = keyData.withUnsafeMutableBytes { pointer in
            SecRandomCopyBytes(kSecRandomDefault, keySize, pointer.baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw SecurityError.keyGenerationFailed
        }
        
        if persistKey, let identifier = identifier {
            try storeCredentials(
                keyData,
                identifier: "key.\(identifier)",
                accessGroup: accessGroup
            )
        }
        
        return keyData
    }
    
    public func retrieveEncryptionKey(
        identifier: String,
        accessGroup: String?
    ) throws -> Data {
        return try retrieveCredentials(
            identifier: "key.\(identifier)",
            accessGroup: accessGroup
        )
    }
    
    public func deleteEncryptionKey(
        identifier: String,
        accessGroup: String?
    ) throws {
        try deleteCredentials(
            identifier: "key.\(identifier)",
            accessGroup: accessGroup
        )
    }
    
    public func encrypt(_ data: Data, using key: Data) throws -> Data {
        guard key.count == 32 else {
            throw SecurityError.invalidCredentials
        }
        
        do {
            let symmetricKey = SymmetricKey(data: key)
            let nonce = try AES.GCM.Nonce(data: Data(repeating: 0, count: 12))
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)
            return sealedBox.combined ?? Data()
        } catch {
            throw SecurityError.encryptionFailed
        }
    }
    
    public func decrypt(_ data: Data, using key: Data) throws -> Data {
        guard key.count == 32 else {
            throw SecurityError.invalidCredentials
        }
        
        do {
            let symmetricKey = SymmetricKey(data: key)
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw SecurityError.decryptionFailed
        }
    }
    
    // MARK: - Private Helpers
    
    private func baseQuery(identifier: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identifier,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
    
    private func convertError(_ status: OSStatus) -> SecurityError {
        switch status {
        case errSecItemNotFound:
            return .credentialsNotFound
        case errSecDuplicateItem:
            return .credentialsExists
        case errSecAuthFailed:
            return .accessDenied
        case errSecUserCanceled:
            return .accessDenied
        case errSecInteractionNotAllowed:
            return .accessDenied
        default:
            return .unknown(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }
}

// MARK: - Secure Enclave Support

extension KeychainSecurityService {
    /// Check if Secure Enclave is available on the current device
    public var isSecureEnclaveAvailable: Bool {
        #if targetEnvironment(simulator)
            return false
        #else
            return true
        #endif
    }
    
    /// Generate a key in the Secure Enclave
    /// - Parameters:
    ///   - tag: Unique identifier for the key
    ///   - accessControl: Access control flags for the key
    /// - Returns: The generated key
    /// - Throws: SecurityError if key generation fails
    public func generateSecureEnclaveKey(
        tag: String,
        accessControl: SecAccessControlCreateFlags
    ) throws -> SecKey? {
        guard isSecureEnclaveAvailable else { return nil }
        
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            accessibility,
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
    
    /// Delete a key from the Secure Enclave
    /// - Parameter tag: The tag of the key to delete
    /// - Throws: SecurityError if deletion fails
    public func deleteSecureEnclaveKey(tag: String) throws {
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

// MARK: - Convenience Methods

public extension KeychainSecurityService {
    /// Creates a default instance for the application
    static let shared = KeychainSecurityService()
}
