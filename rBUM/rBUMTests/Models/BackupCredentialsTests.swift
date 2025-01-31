//
//  BackupCredentialsTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
import Security
@testable import rBUM

struct BackupCredentialsTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup credentials with password", tags: ["basic", "model", "security"])
    func testPasswordInitialization() throws {
        // Given
        let repositoryId = UUID()
        let password = "test-password-123"
        
        // When
        let credentials = BackupCredentials(
            repositoryId: repositoryId,
            password: password
        )
        
        // Then
        #expect(credentials.repositoryId == repositoryId)
        #expect(credentials.hasPassword)
        #expect(!credentials.hasKeyFile)
        #expect(credentials.keyFilePath == nil)
        
        // Password should be securely stored and not directly accessible
        #expect(credentials.password == nil)
    }
    
    @Test("Initialize backup credentials with key file", tags: ["basic", "model", "security"])
    func testKeyFileInitialization() throws {
        // Given
        let repositoryId = UUID()
        let keyFilePath = URL(fileURLWithPath: "/test/key.pem")
        
        // When
        let credentials = BackupCredentials(
            repositoryId: repositoryId,
            keyFilePath: keyFilePath
        )
        
        // Then
        #expect(credentials.repositoryId == repositoryId)
        #expect(!credentials.hasPassword)
        #expect(credentials.hasKeyFile)
        #expect(credentials.keyFilePath == keyFilePath)
    }
    
    // MARK: - Password Tests
    
    @Test("Handle secure password storage", tags: ["model", "security", "password"])
    func testSecurePasswordStorage() throws {
        // Given
        let repositoryId = UUID()
        let password = "test-password-123"
        
        // When
        let credentials = BackupCredentials(
            repositoryId: repositoryId,
            password: password
        )
        
        // Then
        // Password should be stored in keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "rBUM",
            kSecAttrAccount as String: repositoryId.uuidString,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        #expect(status == errSecSuccess)
        if let passwordData = result as? Data,
           let storedPassword = String(data: passwordData, encoding: .utf8) {
            #expect(storedPassword == password)
        } else {
            #expect(false, "Password not found in keychain")
        }
    }
    
    @Test("Handle password updates", tags: ["model", "security", "password"])
    func testPasswordUpdates() throws {
        // Given
        let repositoryId = UUID()
        var credentials = BackupCredentials(
            repositoryId: repositoryId,
            password: "old-password"
        )
        
        // When
        credentials.updatePassword("new-password")
        
        // Then
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "rBUM",
            kSecAttrAccount as String: repositoryId.uuidString,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        #expect(status == errSecSuccess)
        if let passwordData = result as? Data,
           let storedPassword = String(data: passwordData, encoding: .utf8) {
            #expect(storedPassword == "new-password")
        } else {
            #expect(false, "Updated password not found in keychain")
        }
    }
    
    // MARK: - Key File Tests
    
    @Test("Handle key file validation", tags: ["model", "security", "keyfile"])
    func testKeyFileValidation() throws {
        let testCases = [
            // Valid paths
            "/test/key.pem",
            "/test/keys/repository.key",
            // Invalid paths
            "",
            "relative/path/key.pem",
            "/test/key.invalid"
        ]
        
        for path in testCases {
            let credentials = BackupCredentials(
                repositoryId: UUID(),
                keyFilePath: URL(fileURLWithPath: path)
            )
            
            let isValid = path.hasPrefix("/") &&
                         (path.hasSuffix(".pem") || path.hasSuffix(".key"))
            
            if isValid {
                #expect(credentials.isValid)
            } else {
                #expect(!credentials.isValid)
            }
        }
    }
    
    @Test("Handle key file updates", tags: ["model", "security", "keyfile"])
    func testKeyFileUpdates() throws {
        // Given
        let repositoryId = UUID()
        var credentials = BackupCredentials(
            repositoryId: repositoryId,
            keyFilePath: URL(fileURLWithPath: "/test/old.key")
        )
        
        // When
        let newPath = URL(fileURLWithPath: "/test/new.key")
        credentials.updateKeyFile(newPath)
        
        // Then
        #expect(credentials.keyFilePath == newPath)
        #expect(credentials.hasKeyFile)
    }
    
    // MARK: - Authentication Tests
    
    @Test("Handle authentication method changes", tags: ["model", "security", "auth"])
    func testAuthenticationChanges() throws {
        // Given
        let repositoryId = UUID()
        var credentials = BackupCredentials(
            repositoryId: repositoryId,
            password: "test-password"
        )
        
        // Test switching from password to key file
        credentials.updateKeyFile(URL(fileURLWithPath: "/test/key.pem"))
        #expect(credentials.hasKeyFile)
        #expect(!credentials.hasPassword)
        
        // Test switching back to password
        credentials.updatePassword("new-password")
        #expect(!credentials.hasKeyFile)
        #expect(credentials.hasPassword)
        
        // Test removing all authentication
        credentials.removeAuthentication()
        #expect(!credentials.hasKeyFile)
        #expect(!credentials.hasPassword)
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare credentials for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let repositoryId = UUID()
        
        let credentials1 = BackupCredentials(
            repositoryId: repositoryId,
            password: "test-password"
        )
        
        let credentials2 = BackupCredentials(
            repositoryId: repositoryId,
            password: "test-password"
        )
        
        let credentials3 = BackupCredentials(
            repositoryId: UUID(),
            password: "test-password"
        )
        
        #expect(credentials1 == credentials2)
        #expect(credentials1 != credentials3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Handle secure serialization", tags: ["model", "security", "serialization"])
    func testSecureSerialization() throws {
        let testCases = [
            // Password credentials
            BackupCredentials(
                repositoryId: UUID(),
                password: "test-password"
            ),
            // Key file credentials
            BackupCredentials(
                repositoryId: UUID(),
                keyFilePath: URL(fileURLWithPath: "/test/key.pem")
            ),
            // No authentication
            BackupCredentials(repositoryId: UUID())
        ]
        
        for credentials in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(credentials)
            let decoded = try decoder.decode(BackupCredentials.self, from: data)
            
            // Then
            #expect(decoded.repositoryId == credentials.repositoryId)
            #expect(decoded.hasPassword == credentials.hasPassword)
            #expect(decoded.hasKeyFile == credentials.hasKeyFile)
            #expect(decoded.keyFilePath == credentials.keyFilePath)
            
            // Ensure password is not serialized
            let json = String(data: data, encoding: .utf8) ?? ""
            #expect(!json.contains("password"))
            #expect(!json.contains("test-password"))
        }
    }
    
    // MARK: - Cleanup
    
    @Test("Clean up credentials from keychain", tags: ["model", "security", "cleanup"])
    func testCleanup() throws {
        // Given
        let repositoryId = UUID()
        let credentials = BackupCredentials(
            repositoryId: repositoryId,
            password: "test-password"
        )
        
        // When
        credentials.cleanup()
        
        // Then
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "rBUM",
            kSecAttrAccount as String: repositoryId.uuidString
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        #expect(status == errSecItemNotFound)
    }
}
