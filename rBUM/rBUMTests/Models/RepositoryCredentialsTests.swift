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
    @Test("Initialize repository credentials with basic properties")
    func testRepositoryCredentialsInitialization() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        
        // When
        let credentials = RepositoryCredentials(
            repositoryId: id,
            repositoryPath: path
        )
        
        // Then
        #expect(credentials.repositoryId == id)
        #expect(credentials.repositoryPath == path)
        #expect(credentials.keyFileName == nil)
        #expect(credentials.createdAt.timeIntervalSinceNow <= 0)
        #expect(credentials.modifiedAt.timeIntervalSinceNow <= 0)
    }
    
    @Test("Initialize repository credentials with key file")
    func testRepositoryCredentialsWithKeyFile() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        let keyFile = "key.txt"
        
        // When
        let credentials = RepositoryCredentials(
            repositoryId: id,
            repositoryPath: path,
            keyFileName: keyFile
        )
        
        // Then
        #expect(credentials.keyFileName == keyFile)
    }
    
    @Test("Generate correct keychain service name")
    func testKeychainServiceName() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        let credentials = RepositoryCredentials(
            repositoryId: id,
            repositoryPath: path
        )
        
        // When
        let serviceName = credentials.keychainService
        
        // Then
        #expect(serviceName == "dev.mpy.rBUM.repository.\(id.uuidString)")
    }
    
    @Test("Generate correct keychain account name")
    func testKeychainAccountName() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        let credentials = RepositoryCredentials(
            repositoryId: id,
            repositoryPath: path
        )
        
        // When
        let accountName = credentials.keychainAccount
        
        // Then
        #expect(accountName == path)
    }
    
    @Test("Compare credentials for equality")
    func testEquatable() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        let credentials1 = RepositoryCredentials(
            repositoryId: id,
            repositoryPath: path
        )
        let credentials2 = RepositoryCredentials(
            repositoryId: id,
            repositoryPath: path
        )
        let credentials3 = RepositoryCredentials(
            repositoryId: UUID(),
            repositoryPath: path
        )
        
        // Then
        #expect(credentials1 == credentials2)
        #expect(credentials1 != credentials3)
    }
    
    @Test("Encode and decode credentials")
    func testCodable() throws {
        // Given
        let id = UUID()
        let path = "/test/path"
        let keyFile = "key.txt"
        let credentials = RepositoryCredentials(
            repositoryId: id,
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
}
