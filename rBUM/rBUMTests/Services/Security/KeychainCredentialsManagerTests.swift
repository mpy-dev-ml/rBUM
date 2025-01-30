//
//  KeychainCredentialsManagerTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
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

final class KeychainCredentialsManagerTests: XCTestCase {
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
        
        XCTAssertEqual(retrieved.password, testCredentials.password)
        XCTAssertEqual(retrieved.repositoryId, testCredentials.repositoryId)
    }
    
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
        try await credentialsManager.store(updatedCredentials)
        let retrieved = try await credentialsManager.retrieve(forId: repositoryId)
        
        XCTAssertEqual(retrieved.password, updatedCredentials.password)
    }
    
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
        
        do {
            _ = try await credentialsManager.retrieve(forId: testCredentials.repositoryId)
            XCTFail("Expected error when retrieving deleted credentials")
        } catch {}
    }
    
    func testRetrieveNonExistentCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager: CredentialsManagerProtocol = KeychainCredentialsManager(keychainService: keychainService)
        let repositoryId = UUID()
        
        do {
            _ = try await credentialsManager.retrieve(forId: repositoryId)
            XCTFail("Expected error when retrieving non-existent credentials")
        } catch {}
    }
    
    func testDeleteNonExistentCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager: CredentialsManagerProtocol = KeychainCredentialsManager(keychainService: keychainService)
        let repositoryId = UUID()
        
        do {
            try await credentialsManager.delete(forId: repositoryId)
            XCTFail("Expected error when deleting non-existent credentials")
        } catch {}
    }
    
    func testStoreDuplicateCredentials() async throws {
        let keychainService = MockKeychainService()
        let credentialsManager: CredentialsManagerProtocol = KeychainCredentialsManager(keychainService: keychainService)
        let repositoryId = UUID()
        let credentials = RepositoryCredentials(
            repositoryId: repositoryId,
            password: "testPassword",
            repositoryPath: "/test/path"
        )
        
        try await credentialsManager.store(credentials)
        
        do {
            try await credentialsManager.store(credentials)
            XCTFail("Expected error when storing duplicate credentials")
        } catch {}
    }
    
    func testKeychainServiceError() async throws {
        let keychainService = MockKeychainService()
        keychainService.shouldThrowError = true
        let credentialsManager: CredentialsManagerProtocol = KeychainCredentialsManager(keychainService: keychainService)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "testPassword",
            repositoryPath: "/test/path"
        )
        
        do {
            try await credentialsManager.store(testCredentials)
            XCTFail("Expected error when keychain service fails")
        } catch {}
    }
}
