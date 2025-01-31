//
//  BackupSecurityTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
import Security
@testable import rBUM

struct BackupSecurityTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup security with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        
        // When
        let security = BackupSecurity(
            id: id,
            repositoryId: repositoryId
        )
        
        // Then
        #expect(security.id == id)
        #expect(security.repositoryId == repositoryId)
        #expect(security.encryptionEnabled)
        #expect(security.keyType == .aes256)
        #expect(security.keyRotationInterval == 90) // Default 90 days
    }
    
    @Test("Initialize backup security with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        let encryptionEnabled = true
        let keyType = BackupKeyType.aes256
        let keyRotationInterval = 30 // 30 days
        let lastKeyRotation = Date()
        
        // When
        let security = BackupSecurity(
            id: id,
            repositoryId: repositoryId,
            encryptionEnabled: encryptionEnabled,
            keyType: keyType,
            keyRotationInterval: keyRotationInterval,
            lastKeyRotation: lastKeyRotation
        )
        
        // Then
        #expect(security.id == id)
        #expect(security.repositoryId == repositoryId)
        #expect(security.encryptionEnabled == encryptionEnabled)
        #expect(security.keyType == keyType)
        #expect(security.keyRotationInterval == keyRotationInterval)
        #expect(security.lastKeyRotation == lastKeyRotation)
    }
    
    // MARK: - Encryption Tests
    
    @Test("Handle encryption settings", tags: ["model", "encryption"])
    func testEncryptionSettings() throws {
        // Given
        var security = BackupSecurity(
            id: UUID(),
            repositoryId: UUID()
        )
        
        // Test encryption toggle
        security.encryptionEnabled = false
        #expect(!security.encryptionEnabled)
        #expect(security.keyType == nil)
        
        security.encryptionEnabled = true
        #expect(security.encryptionEnabled)
        #expect(security.keyType == .aes256)
    }
    
    // MARK: - Key Management Tests
    
    @Test("Handle key management", tags: ["model", "keys"])
    func testKeyManagement() throws {
        // Given
        var security = BackupSecurity(
            id: UUID(),
            repositoryId: UUID()
        )
        
        // Test key generation
        let key = security.generateKey()
        #expect(key != nil)
        #expect(key?.count == 32) // 256 bits
        
        // Test key storage
        let storedKey = security.storeKey(key!)
        #expect(storedKey)
        
        // Test key retrieval
        let retrievedKey = security.retrieveKey()
        #expect(retrievedKey != nil)
        #expect(retrievedKey == key)
        
        // Test key deletion
        security.deleteKey()
        let deletedKey = security.retrieveKey()
        #expect(deletedKey == nil)
    }
    
    // MARK: - Key Rotation Tests
    
    @Test("Handle key rotation", tags: ["model", "rotation"])
    func testKeyRotation() throws {
        let testCases: [(Int, Date, Bool)] = [
            (90, Date(timeIntervalSinceNow: -91 * 24 * 3600), true),  // Over 90 days
            (90, Date(timeIntervalSinceNow: -89 * 24 * 3600), false), // Under 90 days
            (30, Date(timeIntervalSinceNow: -31 * 24 * 3600), true),  // Over 30 days
            (30, Date(timeIntervalSinceNow: -29 * 24 * 3600), false)  // Under 30 days
        ]
        
        for (interval, lastRotation, shouldRotate) in testCases {
            var security = BackupSecurity(
                id: UUID(),
                repositoryId: UUID(),
                keyRotationInterval: interval,
                lastKeyRotation: lastRotation
            )
            
            #expect(security.shouldRotateKey() == shouldRotate)
            
            if shouldRotate {
                security.rotateKey()
                #expect(security.lastKeyRotation?.timeIntervalSinceNow ?? 0 > lastRotation.timeIntervalSinceNow)
            }
        }
    }
    
    // MARK: - Password Tests
    
    @Test("Handle password management", tags: ["model", "password"])
    func testPasswordManagement() throws {
        // Given
        var security = BackupSecurity(
            id: UUID(),
            repositoryId: UUID()
        )
        
        // Test password validation
        let testCases = [
            ("short", false),
            ("no-special-chars", false),
            ("no-numbers", false),
            ("Valid1Password!", true),
            ("AnotherValid2Password@", true)
        ]
        
        for (password, isValid) in testCases {
            #expect(security.isValidPassword(password) == isValid)
        }
        
        // Test password hashing
        let password = "Valid1Password!"
        let hash = security.hashPassword(password)
        #expect(hash != nil)
        #expect(hash != password)
        
        // Test password verification
        #expect(security.verifyPassword(password, against: hash!))
        #expect(!security.verifyPassword("WrongPassword1!", against: hash!))
    }
    
    // MARK: - Certificate Tests
    
    @Test("Handle certificate management", tags: ["model", "certificates"])
    func testCertificateManagement() throws {
        // Given
        var security = BackupSecurity(
            id: UUID(),
            repositoryId: UUID()
        )
        
        // Test certificate generation
        let cert = security.generateCertificate()
        #expect(cert != nil)
        
        // Test certificate validation
        #expect(security.isValidCertificate(cert!))
        
        // Test certificate storage
        let stored = security.storeCertificate(cert!)
        #expect(stored)
        
        // Test certificate retrieval
        let retrieved = security.retrieveCertificate()
        #expect(retrieved != nil)
        #expect(retrieved == cert)
    }
    
    // MARK: - Audit Tests
    
    @Test("Handle security auditing", tags: ["model", "audit"])
    func testSecurityAuditing() throws {
        // Given
        var security = BackupSecurity(
            id: UUID(),
            repositoryId: UUID()
        )
        
        // Test audit logging
        security.logSecurityEvent(.keyRotation)
        security.logSecurityEvent(.encryptionEnabled)
        
        // Test audit retrieval
        let logs = security.getSecurityLogs()
        #expect(logs.count == 2)
        #expect(logs[0].type == .keyRotation)
        #expect(logs[1].type == .encryptionEnabled)
        
        // Test audit filtering
        let keyRotationLogs = security.getSecurityLogs(ofType: .keyRotation)
        #expect(keyRotationLogs.count == 1)
        #expect(keyRotationLogs[0].type == .keyRotation)
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare security settings for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let security1 = BackupSecurity(
            id: UUID(),
            repositoryId: UUID(),
            encryptionEnabled: true,
            keyType: .aes256
        )
        
        let security2 = BackupSecurity(
            id: security1.id,
            repositoryId: security1.repositoryId,
            encryptionEnabled: true,
            keyType: .aes256
        )
        
        let security3 = BackupSecurity(
            id: UUID(),
            repositoryId: security1.repositoryId,
            encryptionEnabled: true,
            keyType: .aes256
        )
        
        #expect(security1 == security2)
        #expect(security1 != security3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup security", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic security
            BackupSecurity(
                id: UUID(),
                repositoryId: UUID()
            ),
            // Full security settings
            BackupSecurity(
                id: UUID(),
                repositoryId: UUID(),
                encryptionEnabled: true,
                keyType: .aes256,
                keyRotationInterval: 30,
                lastKeyRotation: Date()
            )
        ]
        
        for security in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(security)
            let decoded = try decoder.decode(BackupSecurity.self, from: data)
            
            // Then
            #expect(decoded.id == security.id)
            #expect(decoded.repositoryId == security.repositoryId)
            #expect(decoded.encryptionEnabled == security.encryptionEnabled)
            #expect(decoded.keyType == security.keyType)
            #expect(decoded.keyRotationInterval == security.keyRotationInterval)
            #expect(decoded.lastKeyRotation == security.lastKeyRotation)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup security properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid security
            (UUID(), UUID(), true, .aes256, 90, true),
            // Invalid key rotation interval
            (UUID(), UUID(), true, .aes256, 0, false),
            // Invalid state (encryption enabled without key type)
            (UUID(), UUID(), true, nil, 90, false)
        ]
        
        for (id, repoId, encrypted, keyType, interval, isValid) in testCases {
            let security = BackupSecurity(
                id: id,
                repositoryId: repoId,
                encryptionEnabled: encrypted,
                keyType: keyType,
                keyRotationInterval: interval
            )
            
            if isValid {
                #expect(security.isValid)
            } else {
                #expect(!security.isValid)
            }
        }
    }
}
