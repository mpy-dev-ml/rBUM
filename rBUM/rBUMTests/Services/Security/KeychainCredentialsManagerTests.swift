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
    // MARK: - Test Setup
    
    struct TestContext {
        let keychainService: MockKeychainService
        let credentialsManager: CredentialsManagerProtocol
        
        init(shouldThrowError: Bool = false) {
            self.keychainService = MockKeychainService()
            self.keychainService.shouldThrowError = shouldThrowError
            self.credentialsManager = KeychainCredentialsManager(keychainService: keychainService)
        }
    }
    
    // MARK: - Credential Storage Tests
    
    @Test("Store and retrieve credentials with various configurations",
          .tags(.core, .security, .integration),
          arguments: [
              (password: "simple-password", path: "/test/path"),
              (password: "Complex!@#$%^&*()", path: "/path/with/special/chars/!@#"),
              (password: "password with spaces", path: "/path with spaces"),
              (password: "unicode", path: "/path/with/unicode/")
          ])
    func testStoreAndRetrieveCredentials(password: String, path: String) async throws {
        // Given
        let context = TestContext()
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: password,
            repositoryPath: path
        )
        
        // When
        try await context.credentialsManager.store(testCredentials)
        let retrieved = try await context.credentialsManager.retrieve(forId: testCredentials.repositoryId)
        
        // Then
        #expect(retrieved.password == testCredentials.password)
        #expect(retrieved.repositoryId == testCredentials.repositoryId)
        #expect(retrieved.repositoryPath == testCredentials.repositoryPath)
    }
    
    @Test("Update credentials with various changes",
          .tags(.core, .security, .integration),
          arguments: [
              (initial: "password1", updated: "newPassword1"),
              (initial: "Complex!@#", updated: "EvenMore!@#$%^"),
              (initial: "short", updated: String(repeating: "a", count: 100))
          ])
    func testUpdateCredentials(initial: String, updated: String) async throws {
        // Given
        let context = TestContext()
        let repositoryId = UUID()
        let path = "/test/path"
        
        let initialCredentials = RepositoryCredentials(
            repositoryId: repositoryId,
            password: initial,
            repositoryPath: path
        )
        let updatedCredentials = RepositoryCredentials(
            repositoryId: repositoryId,
            password: updated,
            repositoryPath: path
        )
        
        // When
        try await context.credentialsManager.store(initialCredentials)
        try await context.credentialsManager.update(updatedCredentials)
        let retrieved = try await context.credentialsManager.retrieve(forId: repositoryId)
        
        // Then
        #expect(retrieved.password == updated)
        #expect(retrieved.repositoryId == repositoryId)
        #expect(retrieved.repositoryPath == path)
    }
    
    // MARK: - Security Tests
    
    @Test("Handle various security scenarios",
          .tags(.core, .security, .error_handling),
          arguments: [
              (operation: "store", error: KeychainError.duplicateItem),
              (operation: "retrieve", error: KeychainError.itemNotFound),
              (operation: "update", error: KeychainError.unexpectedStatus(errSecItemNotFound)),
              (operation: "delete", error: KeychainError.unexpectedStatus(errSecItemNotFound))
          ])
    func testSecurityScenarios(operation: String, error: KeychainError) async throws {
        // Given
        let context = TestContext(shouldThrowError: true)
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "testPassword",
            repositoryPath: "/test/path"
        )
        
        // When/Then
        switch operation {
        case "store":
            await #expect(throws: error) {
                try await context.credentialsManager.store(testCredentials)
            }
        case "retrieve":
            await #expect(throws: error) {
                _ = try await context.credentialsManager.retrieve(forId: testCredentials.repositoryId)
            }
        case "update":
            await #expect(throws: error) {
                try await context.credentialsManager.update(testCredentials)
            }
        case "delete":
            await #expect(throws: error) {
                try await context.credentialsManager.delete(forId: testCredentials.repositoryId)
            }
        default:
            #expect(false, "Unknown operation: \(operation)")
        }
    }
    
    @Test("Prevent credential leakage",
          .tags(.core, .security, .validation))
    func testCredentialLeakage() async throws {
        // Given
        let context = TestContext()
        let sensitivePassword = "SuperSecretPassword!@#"
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: sensitivePassword,
            repositoryPath: "/test/path"
        )
        
        // When
        try await context.credentialsManager.store(testCredentials)
        
        // Then
        // Verify password is not stored in plain text
        let rawKeychainData = context.keychainService.passwords
        for (_, accounts) in rawKeychainData {
            for (_, storedValue) in accounts {
                #expect(storedValue != sensitivePassword, "Password should not be stored in plain text")
            }
        }
    }
    
    @Test("Handle concurrent access",
          .tags(.core, .security, .concurrency))
    func testConcurrentAccess() async throws {
        // Given
        let context = TestContext()
        let repositoryId = UUID()
        let path = "/test/path"
        let passwords = ["password1", "password2", "password3", "password4"]
        
        // When
        try await withThrowingTaskGroup(of: Void.self) { group in
            for password in passwords {
                group.addTask {
                    let credentials = RepositoryCredentials(
                        repositoryId: repositoryId,
                        password: password,
                        repositoryPath: path
                    )
                    try await context.credentialsManager.update(credentials)
                }
            }
            try await group.waitForAll()
        }
        
        // Then
        let finalCredentials = try await context.credentialsManager.retrieve(forId: repositoryId)
        #expect(passwords.contains(finalCredentials.password))
    }
    
    @Test("Handle credential deletion securely",
          .tags(.core, .security, .cleanup))
    func testSecureCredentialDeletion() async throws {
        // Given
        let context = TestContext()
        let testCredentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "testPassword",
            repositoryPath: "/test/path"
        )
        
        // When
        try await context.credentialsManager.store(testCredentials)
        try await context.credentialsManager.delete(forId: testCredentials.repositoryId)
        
        // Then
        // Verify credential is completely removed
        await #expect(throws: CredentialsError.notFound) {
            _ = try await context.credentialsManager.retrieve(forId: testCredentials.repositoryId)
        }
        
        // Verify no traces in keychain service
        let rawKeychainData = context.keychainService.passwords
        for (_, accounts) in rawKeychainData {
            for (_, storedValue) in accounts {
                #expect(storedValue != testCredentials.password)
            }
        }
    }
}
