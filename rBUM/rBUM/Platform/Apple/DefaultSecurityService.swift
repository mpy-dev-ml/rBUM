//
//  DefaultSecurityService.swift
//  rBUM
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation
import Security
import LocalAuthentication
import Logging
import Core

/// macOS implementation of security service
final class DefaultSecurityService: SecurityServiceProtocol {
    // MARK: - Properties
    
    private let logger: Logger
    private let securityClass = kSecClassGenericPassword
    private let keychainAccessGroup: String?
    
    /// Whether hardware security module is available
    var isSecureHardwareAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    // MARK: - Initialization
    
    init(
        logger: Logger = Logger(label: "dev.mpy.rbum.security.apple"),
        keychainAccessGroup: String? = nil
    ) {
        self.logger = logger
        self.keychainAccessGroup = keychainAccessGroup
        
        logger.debug("macOS security service initialised")
    }
    
    // MARK: - Sandbox Operations
    
    func createSecurityScopedBookmark(
        for url: URL,
        readOnly: Bool,
        requiredKeys: Set<URLResourceKey>?
    ) async throws -> Data {
        logger.debug("Creating security-scoped bookmark", metadata: [
            "path": .string(url.path),
            "readOnly": .string("\(readOnly)")
        ])
        
        do {
            var options: URL.BookmarkCreationOptions = [.withSecurityScope]
            if readOnly {
                options.insert(.securityScopeAllowOnlyReadAccess)
            }
            
            let bookmark = try url.bookmarkData(
                options: options,
                includingResourceValuesForKeys: requiredKeys,
                relativeTo: nil
            )
            
            logger.info("Created security-scoped bookmark", metadata: [
                "path": .string(url.path),
                "readOnly": .string("\(readOnly)")
            ])
            
            return bookmark
            
        } catch {
            logger.error("Failed to create bookmark", metadata: [
                "error": .string(error.localizedDescription),
                "path": .string(url.path)
            ])
            throw SecurityError.bookmarkCreationFailed
        }
    }
    
    func resolveSecurityScopedBookmark(_ bookmark: Data) async throws -> URL {
        logger.debug("Resolving security-scoped bookmark")
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                logger.warning("Bookmark is stale", metadata: [
                    "path": .string(url.path)
                ])
                throw SecurityError.bookmarkStale
            }
            
            logger.info("Resolved security-scoped bookmark", metadata: [
                "path": .string(url.path)
            ])
            
            return url
            
        } catch let error as SecurityError {
            throw error
        } catch {
            logger.error("Failed to resolve bookmark", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw SecurityError.bookmarkResolutionFailed
        }
    }
    
    func startAccessingSecurityScopedResource(_ bookmark: Data) async throws -> URL {
        logger.debug("Starting security-scoped resource access")
        
        let url = try await resolveSecurityScopedBookmark(bookmark)
        
        guard url.startAccessingSecurityScopedResource() else {
            logger.error("Failed to start accessing resource", metadata: [
                "path": .string(url.path)
            ])
            throw SecurityError.accessDenied
        }
        
        logger.info("Started accessing security-scoped resource", metadata: [
            "path": .string(url.path)
        ])
        
        return url
    }
    
    func stopAccessingSecurityScopedResource(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
        logger.debug("Stopped accessing security-scoped resource", metadata: [
            "path": .string(url.path)
        ])
    }
    
    // MARK: - Keychain Operations
    
    func storeCredentials(
        _ credentials: Data,
        identifier: String,
        accessGroup: String?,
        accessControl: Any?
    ) throws {
        var query = baseQuery(for: identifier, accessGroup: accessGroup)
        query[kSecValueData as String] = credentials
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw mapKeychainError(status)
        }
    }
    
    func retrieveCredentials(
        identifier: String,
        accessGroup: String?
    ) throws -> Data {
        var query = baseQuery(for: identifier, accessGroup: accessGroup)
        query[kSecReturnData as String] = true
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw mapKeychainError(status)
        }
        
        return data
    }
    
    func deleteCredentials(
        identifier: String,
        accessGroup: String?
    ) throws {
        let query = baseQuery(for: identifier, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw mapKeychainError(status)
        }
    }
    
    func updateCredentials(
        _ credentials: Data,
        identifier: String,
        accessGroup: String?
    ) throws {
        let query = baseQuery(for: identifier, accessGroup: accessGroup)
        let attributes = [kSecValueData as String: credentials]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw mapKeychainError(status)
        }
    }
    
    func hasCredentials(
        identifier: String,
        accessGroup: String?
    ) -> Bool {
        var query = baseQuery(for: identifier, accessGroup: accessGroup)
        query[kSecReturnData as String] = false
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Encryption Operations
    
    func generateEncryptionKey(
        bits: Int,
        persistKey: Bool,
        identifier: String?,
        accessGroup: String?
    ) throws -> Data {
        guard bits == 128 || bits == 256 else {
            throw SecurityError.invalidKey
        }
        
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            &error
        ) else {
            throw SecurityError.keyGenerationFailed
        }
        
        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeAES,
            kSecAttrKeySizeInBits as String: bits,
            kSecAttrAccessControl as String: access
        ]
        
        if persistKey, let identifier = identifier {
            attributes[kSecAttrApplicationTag as String] = identifier
            if let accessGroup = accessGroup {
                attributes[kSecAttrAccessGroup as String] = accessGroup
            }
        }
        
        var error2: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error2) else {
            throw SecurityError.keyGenerationFailed
        }
        
        guard let data = SecKeyCopyExternalRepresentation(key, &error2) as Data? else {
            throw SecurityError.keyGenerationFailed
        }
        
        return data
    }
    
    func retrieveEncryptionKey(
        identifier: String,
        accessGroup: String?
    ) throws -> Data {
        var query = baseQuery(for: identifier, accessGroup: accessGroup)
        query[kSecReturnRef as String] = true
        query[kSecClass as String] = kSecClassKey
        query[kSecAttrKeyType as String] = kSecAttrKeyTypeAES
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let key = result as? SecKey else {
            throw mapKeychainError(status)
        }
        
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            throw SecurityError.keyNotFound
        }
        
        return data
    }
    
    func deleteEncryptionKey(
        identifier: String,
        accessGroup: String?
    ) throws {
        var query = baseQuery(for: identifier, accessGroup: accessGroup)
        query[kSecClass as String] = kSecClassKey
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw mapKeychainError(status)
        }
    }
    
    func encrypt(_ data: Data, using key: Data) throws -> Data {
        guard let keyData = key as? NSData else {
            throw SecurityError.invalidKey
        }
        
        let algorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
        
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(
            key as! SecKey,
            algorithm,
            data as CFData,
            &error
        ) as Data? else {
            throw SecurityError.encryptionFailed
        }
        
        return encrypted
    }
    
    func decrypt(_ data: Data, using key: Data) throws -> Data {
        guard let keyData = key as? NSData else {
            throw SecurityError.invalidKey
        }
        
        let algorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
        
        var error: Unmanaged<CFError>?
        guard let decrypted = SecKeyCreateDecryptedData(
            key as! SecKey,
            algorithm,
            data as CFData,
            &error
        ) as Data? else {
            throw SecurityError.decryptionFailed
        }
        
        return decrypted
    }
    
    // MARK: - Private Methods
    
    private func baseQuery(for identifier: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: securityClass,
            kSecAttrAccount as String: identifier
        ]
        
        if let accessGroup = accessGroup ?? keychainAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
    
    private func mapKeychainError(_ status: OSStatus) -> SecurityError {
        switch status {
        case errSecItemNotFound:
            return .credentialsNotFound
        case errSecDuplicateItem:
            return .credentialsExists
        case errSecAuthFailed:
            return .accessDenied
        default:
            return .invalidCredentials
        }
    }
}
