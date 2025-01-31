//
//  RepositoryCredentialsTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct RepositoryCredentialsTests {
    // MARK: - Basic Tests
    
    @Test("Initialize repository credentials with basic properties", tags: ["basic", "model"])
    func testRepositoryCredentialsInitialization() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        
        // When
        let credentials = RepositoryCredentials(
            repositoryId: id,
            password: "test-password",
            repositoryPath: path
        )
        
        // Then
        #expect(credentials.repositoryId == id)
        #expect(credentials.repositoryPath == path)
        #expect(credentials.keyFileName == nil)
        #expect(credentials.createdAt.timeIntervalSinceNow <= 0)
        #expect(credentials.modifiedAt.timeIntervalSinceNow <= 0)
    }
    
    @Test("Initialize repository credentials with key file", tags: ["basic", "model", "security"])
    func testRepositoryCredentialsWithKeyFile() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        let keyFile = "key.txt"
        
        // When
        let credentials = RepositoryCredentials(
            repositoryId: id,
            password: "test-password",
            repositoryPath: path,
            keyFileName: keyFile
        )
        
        // Then
        #expect(credentials.keyFileName == keyFile)
    }
    
    // MARK: - Keychain Integration Tests
    
    @Test("Generate correct keychain service name", tags: ["keychain", "security"])
    func testKeychainServiceName() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        let credentials = RepositoryCredentials(
            repositoryId: id,
            password: "test-password",
            repositoryPath: path
        )
        
        // When
        let serviceName = credentials.keychainService
        
        // Then
        #expect(serviceName == "dev.mpy.rBUM.repository.\(id.uuidString)")
    }
    
    @Test("Generate correct keychain account name", tags: ["keychain", "security"])
    func testKeychainAccountName() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        let credentials = RepositoryCredentials(
            repositoryId: id,
            password: "test-password",
            repositoryPath: path
        )
        
        // When
        let accountName = credentials.keychainAccount
        
        // Then
        #expect(accountName == path)
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare credentials for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        let credentials1 = RepositoryCredentials(
            repositoryId: id,
            password: "test-password",
            repositoryPath: path
        )
        let credentials2 = RepositoryCredentials(
            repositoryId: id,
            password: "test-password",
            repositoryPath: path
        )
        let credentials3 = RepositoryCredentials(
            repositoryId: UUID(),
            password: "test-password",
            repositoryPath: path
        )
        
        // Then
        #expect(credentials1 == credentials2)
        #expect(credentials1 != credentials3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode credentials", tags: ["model", "serialization"])
    func testCodable() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        let keyFile = "key.txt"
        let credentials = RepositoryCredentials(
            repositoryId: id,
            password: "test-password",
            repositoryPath: path,
            keyFileName: keyFile
        )
        
        // When
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(credentials)
        let decoded = try decoder.decode(RepositoryCredentials.self, from: data)
        
        // Then
        #expect(credentials == decoded)
        #expect(decoded.repositoryId == id)
        #expect(decoded.repositoryPath == path)
        #expect(decoded.keyFileName == keyFile)
    }
    
    // MARK: - Parameterized Tests
    
    @Test("Handle various credential formats", tags: ["parameterized", "model", "security"])
    func testCredentialFormats() throws {
        let testCases = [
            // Test basic credentials
            (
                "Basic credentials",
                RepositoryCredentials(
                    repositoryId: UUID(),
                    password: "simple-password",
                    repositoryPath: "/basic/path"
                )
            ),
            // Test credentials with spaces
            (
                "Credentials with spaces",
                RepositoryCredentials(
                    repositoryId: UUID(),
                    password: "password with spaces",
                    repositoryPath: "/path with spaces/repo"
                )
            ),
            // Test credentials with special characters
            (
                "Credentials with special characters",
                RepositoryCredentials(
                    repositoryId: UUID(),
                    password: "password!@#$%^&*()",
                    repositoryPath: "/path/with/special/chars/!@#$/repo"
                )
            ),
            // Test credentials with very long values
            (
                "Long credentials",
                RepositoryCredentials(
                    repositoryId: UUID(),
                    password: String(repeating: "a", count: 1000),
                    repositoryPath: "/very/long/path/" + String(repeating: "a", count: 1000)
                )
            ),
            // Test credentials with empty password
            (
                "Empty password",
                RepositoryCredentials(
                    repositoryId: UUID(),
                    password: "",
                    repositoryPath: "/empty/password/repo"
                )
            ),
            // Test credentials with key file
            (
                "With key file",
                RepositoryCredentials(
                    repositoryId: UUID(),
                    password: "password",
                    repositoryPath: "/path/with/key",
                    keyFileName: "key.txt"
                )
            )
        ]
        
        for (name, credentials) in testCases {
            // Test encoding/decoding
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(credentials)
            let decoded = try decoder.decode(RepositoryCredentials.self, from: data)
            
            // Verify all properties are preserved
            #expect(decoded.repositoryId == credentials.repositoryId, "Failed to preserve ID for: \(name)")
            #expect(decoded.password == credentials.password, "Failed to preserve password for: \(name)")
            #expect(decoded.repositoryPath == credentials.repositoryPath, "Failed to preserve path for: \(name)")
            #expect(decoded.keyFileName == credentials.keyFileName, "Failed to preserve key file for: \(name)")
            
            // Verify keychain integration
            let serviceName = credentials.keychainService
            let accountName = credentials.keychainAccount
            #expect(serviceName.contains(credentials.repositoryId.uuidString), "Invalid service name for: \(name)")
            #expect(accountName == credentials.repositoryPath, "Invalid account name for: \(name)")
        }
    }
    
    @Test("Validate timestamp behavior", tags: ["model", "timestamp"])
    func testTimestampBehavior() throws {
        // Given initial credentials
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "test-password",
            repositoryPath: "/test/path"
        )
        
        // Initial timestamps should be close to now
        let now = Date()
        #expect(abs(credentials.createdAt.timeIntervalSince(now)) < 1.0)
        #expect(abs(credentials.modifiedAt.timeIntervalSince(now)) < 1.0)
        #expect(credentials.createdAt == credentials.modifiedAt)
        
        // Sleep to ensure time difference
        Thread.sleep(forTimeInterval: 0.1)
        
        // When updating
        var updated = credentials
        updated.password = "new-password"
        
        // Then timestamps should reflect the change
        #expect(updated.createdAt == credentials.createdAt)
        #expect(updated.modifiedAt > credentials.modifiedAt)
        #expect(updated.modifiedAt > updated.createdAt)
    }
    
    @Test("Handle invalid paths", tags: ["model", "validation"])
    func testInvalidPaths() throws {
        let invalidPaths = [
            "", // Empty path
            "relative/path", // Relative path
            "/path/with/null/\0/character", // Path with null character
            "/path/with/newline\n/character", // Path with newline
            String(repeating: "a", count: 4096) // Extremely long path
        ]
        
        for path in invalidPaths {
            // Attempt to create credentials with invalid path
            let credentials = RepositoryCredentials(
                repositoryId: UUID(),
                password: "test-password",
                repositoryPath: path
            )
            
            // Verify path is normalized or rejected
            let accountName = credentials.keychainAccount
            #expect(!accountName.contains("\0"))
            #expect(!accountName.contains("\n"))
            #expect(accountName.count <= 1024)
        }
    }
}
