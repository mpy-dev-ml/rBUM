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
        let credentialsManager: CredentialsManagerProtocol = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "testPassword",
            repositoryPath: "/test/path"
        )
        
        try await credentialsManager.store(testCredentials)
        let retrieved = try await credentialsManager.retrieve(forId: testCredentials.repositoryId)
        
        #expect(retrieved.password == testCredentials.password)
        #expect(retrieved.repositoryId == testCredentials.repositoryId)
    }
    
    @Test("Store updated credentials")
    func testUpdateCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager: CredentialsManagerProtocol = KeychainCredentialsManager(keychainService: keychainService)
        let repositoryId = UUID()
        let initialCredentials = RepositoryCredentials(
            repositoryId: repositoryId,
            password: "initialPassword",
            repositoryPath: "/test/path"
        )
        let updatedCredentials = RepositoryCredentials(
            repositoryId: repositoryId,
            password: "updatedPassword",
            repositoryPath: "/test/path"
        )
        
        try await credentialsManager.store(initialCredentials)
        try await credentialsManager.store(updatedCredentials) // Store the updated credentials
        let retrieved = try await credentialsManager.retrieve(forId: repositoryId)
        
        #expect(retrieved.password == updatedCredentials.password)
    }
    
    @Test("Delete credentials")
    func testDeleteCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager: CredentialsManagerProtocol = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "testPassword",
            repositoryPath: "/test/path"
        )
        
        try await credentialsManager.store(testCredentials)
        try await credentialsManager.delete(forId: testCredentials.repositoryId)
        
        var didThrow = false
        do {
            _ = try await credentialsManager.retrieve(forId: testCredentials.repositoryId)
        } catch is CredentialsError {
            didThrow = true
        }
        #expect(didThrow, "Expected CredentialsError.notFound to be thrown")
    }
    
    @Test("Handle keychain errors")
    func testKeychainErrors() async throws {
        let keychainService = MockKeychainService()
        keychainService.shouldThrowError = true
        let credentialsManager: CredentialsManagerProtocol = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "testPassword",
            repositoryPath: "/test/path"
        )
        
        var didThrow = false
        do {
            try await credentialsManager.store(testCredentials)
        } catch is KeychainError {
            didThrow = true
        }
        #expect(didThrow, "Expected KeychainError to be thrown")
    }
}
