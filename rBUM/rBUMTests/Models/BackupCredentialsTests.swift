//
//  BackupCredentialsTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupCredentials functionality
struct BackupCredentialsTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let keychain: MockKeychain
        let notificationCenter: MockNotificationCenter
        
        init() {
            self.keychain = MockKeychain()
            self.notificationCenter = MockNotificationCenter()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            keychain.reset()
            notificationCenter.reset()
        }
        
        /// Create test credentials
        func createCredentials(
            username: String = MockData.Credentials.validUsername,
            password: String = MockData.Credentials.validPassword,
            repository: Repository = MockData.Repository.validRepository,
            isEnabled: Bool = true
        ) -> BackupCredentials {
            BackupCredentials(
                username: username,
                password: password,
                repository: repository,
                isEnabled: isEnabled
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize with default values", tags: ["init", "credentials"])
    func testDefaultInitialization() throws {
        // Given: Default credentials parameters
        let context = TestContext()
        
        // When: Creating credentials
        let credentials = context.createCredentials()
        
        // Then: Credentials are configured correctly
        #expect(credentials.username == MockData.Credentials.validUsername)
        #expect(credentials.password == MockData.Credentials.validPassword)
        #expect(credentials.repository == MockData.Repository.validRepository)
        #expect(credentials.isEnabled)
    }
    
    @Test("Initialize with custom values", tags: ["init", "credentials"])
    func testCustomInitialization() throws {
        // Given: Custom credentials parameters
        let context = TestContext()
        let customUsername = "custom-user"
        let customPassword = "custom-pass"
        let customRepository = MockData.Repository.customRepository
        
        // When: Creating credentials
        let credentials = context.createCredentials(
            username: customUsername,
            password: customPassword,
            repository: customRepository,
            isEnabled: false
        )
        
        // Then: Credentials are configured correctly
        #expect(credentials.username == customUsername)
        #expect(credentials.password == customPassword)
        #expect(credentials.repository == customRepository)
        #expect(!credentials.isEnabled)
    }
    
    // MARK: - Persistence Tests
    
    @Test("Save and load credentials", tags: ["persistence", "credentials"])
    func testPersistence() throws {
        // Given: Credentials with custom values
        let context = TestContext()
        let credentials = context.createCredentials(
            username: "test-user",
            password: "test-pass",
            isEnabled: false
        )
        
        // When: Saving and loading credentials
        credentials.save(to: context.keychain)
        let loaded = BackupCredentials.load(from: context.keychain, forRepository: credentials.repository)
        
        // Then: Loaded credentials match original
        #expect(loaded?.username == credentials.username)
        #expect(loaded?.password == credentials.password)
        #expect(loaded?.repository == credentials.repository)
        #expect(loaded?.isEnabled == credentials.isEnabled)
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate credentials", tags: ["validation", "credentials"])
    func testValidation() throws {
        // Given: Credentials with various validation scenarios
        let context = TestContext()
        let testCases: [(BackupCredentials, Bool)] = [
            // Valid credentials
            (context.createCredentials(), true),
            
            // Invalid - empty username
            (context.createCredentials(username: ""), false),
            
            // Invalid - empty password
            (context.createCredentials(password: ""), false),
            
            // Invalid - invalid repository
            (context.createCredentials(repository: MockData.Repository.invalidRepository), false)
        ]
        
        // When/Then: Test validation
        for (credentials, isValid) in testCases {
            #expect(credentials.isValid() == isValid)
        }
    }
    
    // MARK: - Security Tests
    
    @Test("Handle secure storage", tags: ["security", "credentials"])
    func testSecureStorage() throws {
        // Given: Credentials and keychain
        let context = TestContext()
        let credentials = context.createCredentials()
        
        // When: Storing credentials
        credentials.save(to: context.keychain)
        
        // Then: Credentials are stored securely
        #expect(context.keychain.isEncrypted)
        #expect(context.keychain.containsCredentials(forRepository: credentials.repository))
    }
    
    @Test("Handle credential updates", tags: ["security", "credentials"])
    func testCredentialUpdates() throws {
        // Given: Initial credentials
        let context = TestContext()
        let credentials = context.createCredentials()
        
        // When: Updating credentials
        credentials.save(to: context.keychain)
        let updatedCredentials = context.createCredentials(
            username: "updated-user",
            password: "updated-pass"
        )
        updatedCredentials.save(to: context.keychain)
        
        // Then: Updated credentials are stored
        let loaded = BackupCredentials.load(from: context.keychain, forRepository: credentials.repository)
        #expect(loaded?.username == updatedCredentials.username)
        #expect(loaded?.password == updatedCredentials.password)
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle edge cases", tags: ["edge", "credentials"])
    func testEdgeCases() throws {
        // Given: Edge case scenarios
        let context = TestContext()
        
        // Test nil keychain
        let emptyKeychain = MockKeychain()
        let loadedCredentials = BackupCredentials.load(from: emptyKeychain, forRepository: MockData.Repository.validRepository)
        #expect(loadedCredentials == nil)
        
        // Test special characters
        let specialChars = "!@#$%^&*()"
        let specialCredentials = context.createCredentials(
            username: "user\(specialChars)",
            password: "pass\(specialChars)"
        )
        specialCredentials.save(to: context.keychain)
        let loadedSpecial = BackupCredentials.load(from: context.keychain, forRepository: specialCredentials.repository)
        #expect(loadedSpecial?.username == specialCredentials.username)
        #expect(loadedSpecial?.password == specialCredentials.password)
        
        // Test maximum length
        let maxLength = String(repeating: "a", count: 1024)
        let maxCredentials = context.createCredentials(
            username: maxLength,
            password: maxLength
        )
        #expect(!maxCredentials.isValid())
    }
}

// MARK: - Mock Implementations

/// Mock implementation of Keychain for testing
final class MockKeychain: KeychainProtocol {
    var storage: [String: (username: String, password: String)] = [:]
    var isEncrypted = true
    
    func save(username: String, password: String, forRepository repository: Repository) {
        storage[repository.id] = (username: username, password: password)
    }
    
    func load(forRepository repository: Repository) -> (username: String, password: String)? {
        storage[repository.id]
    }
    
    func containsCredentials(forRepository repository: Repository) -> Bool {
        storage[repository.id] != nil
    }
    
    func delete(forRepository repository: Repository) {
        storage.removeValue(forKey: repository.id)
    }
    
    func reset() {
        storage.removeAll()
        isEncrypted = true
    }
}

/// Mock implementation of NotificationCenter for testing
final class MockNotificationCenter: NotificationCenter {
    var postCalled = false
    var lastNotification: Notification?
    
    override func post(_ notification: Notification) {
        postCalled = true
        lastNotification = notification
    }
    
    func reset() {
        postCalled = false
        lastNotification = nil
    }
}
