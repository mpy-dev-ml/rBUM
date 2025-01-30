//
//  KeychainCredentialsManagerTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Security
import Foundation
@testable import rBUM

/// Mock implementation of KeychainService for testing
final class MockKeychainService: KeychainServiceProtocol {
    // MARK: - Properties
    var passwords: [String: [String: String]] = [:]
    var shouldThrowError = false
    
    // MARK: - KeychainServiceProtocol Methods
    func storePassword(_ password: String, forService service: String, account: String) async throws {
        if shouldThrowError { throw KeychainError.unexpectedStatus(errSecDuplicateItem) }
        if passwords[service]?[account] != nil {
            throw KeychainError.duplicateItem
        }
        passwords[service] = passwords[service] ?? [:]
        passwords[service]?[account] = password
    }
    
    func retrievePassword(forService service: String, account: String) async throws -> String {
        if shouldThrowError { throw KeychainError.unexpectedStatus(errSecItemNotFound) }
        guard let password = passwords[service]?[account] else {
            throw KeychainError.itemNotFound
        }
        return password
    }
    
    func updatePassword(_ password: String, forService service: String, account: String) async throws {
        if shouldThrowError { throw KeychainError.unexpectedStatus(errSecItemNotFound) }
        guard passwords[service]?[account] != nil else {
            throw KeychainError.itemNotFound
        }
        passwords[service]?[account] = password
    }
    
    func deletePassword(forService service: String, account: String) async throws {
        if shouldThrowError { throw KeychainError.unexpectedStatus(errSecItemNotFound) }
        guard passwords[service]?[account] != nil else {
            throw KeychainError.itemNotFound
        }
        passwords[service]?[account] = nil
    }
}

struct KeychainCredentialsManagerTests {
    @Test("Store and retrieve credentials")
    func testStoreCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            repositoryPath: "/test/path"
        )
        
        // Given
        let password = "testPassword"
        
        // When
        try await credentialsManager.storeCredentials(password, for: testCredentials)
        
        // Then
        let retrieved = try await credentialsManager.retrievePassword(for: testCredentials)
        #expect(retrieved == password)
    }
    
    @Test("Prevent storing duplicate credentials")
    func testStoreCredentialsDuplicate() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            repositoryPath: "/test/path"
        )
        
        // Given
        let password = "testPassword"
        try await credentialsManager.storeCredentials(password, for: testCredentials)
        
        // When/Then
        await #expect(throws: KeychainError.duplicateItem) {
            try await credentialsManager.storeCredentials("newPassword", for: testCredentials)
        }
    }
    
    @Test("Handle retrieving nonexistent credentials")
    func testRetrieveNonexistentCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            repositoryPath: "/test/path"
        )
        
        await #expect(throws: KeychainError.itemNotFound) {
            _ = try await credentialsManager.retrievePassword(for: testCredentials)
        }
    }
    
    @Test("Update existing credentials")
    func testUpdateCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            repositoryPath: "/test/path"
        )
        
        // Given
        let password = "testPassword"
        try await credentialsManager.storeCredentials(password, for: testCredentials)
        
        // When
        let newPassword = "newPassword"
        try await credentialsManager.updatePassword(newPassword, for: testCredentials)
        
        // Then
        let retrieved = try await credentialsManager.retrievePassword(for: testCredentials)
        #expect(retrieved == newPassword)
    }
    
    @Test("Handle updating nonexistent credentials")
    func testUpdateNonexistentCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            repositoryPath: "/test/path"
        )
        
        await #expect(throws: KeychainError.itemNotFound) {
            try await credentialsManager.updatePassword("new", for: testCredentials)
        }
    }
    
    @Test("Delete existing credentials")
    func testDeleteCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            repositoryPath: "/test/path"
        )
        
        // Given
        let password = "testPassword"
        try await credentialsManager.storeCredentials(password, for: testCredentials)
        
        // When
        try await credentialsManager.deleteCredentials(testCredentials)
        
        // Then
        await #expect(throws: KeychainError.itemNotFound) {
            _ = try await credentialsManager.retrievePassword(for: testCredentials)
        }
    }
    
    @Test("Handle deleting nonexistent credentials")
    func testDeleteNonexistentCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            repositoryPath: "/test/path"
        )
        
        await #expect(throws: KeychainError.itemNotFound) {
            try await credentialsManager.deleteCredentials(testCredentials)
        }
    }
    
    @Test("Handle keychain service errors")
    func testKeychainServiceError() async throws {
        let keychainService = MockKeychainService()
        keychainService.shouldThrowError = true
        let credentialsManager = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            repositoryPath: "/test/path"
        )
        
        await #expect(throws: KeychainError.unexpectedStatus(errSecDuplicateItem)) {
            try await credentialsManager.storeCredentials("test", for: testCredentials)
        }
    }
}
