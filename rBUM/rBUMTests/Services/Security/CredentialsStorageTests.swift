//
//  CredentialsStorageTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for CredentialsStorage functionality
struct CredentialsStorageTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let keychain: MockKeychain
        let notificationCenter: MockNotificationCenter
        let securityService: MockSecurityService
        let encoder: JSONEncoder
        let decoder: JSONDecoder
        
        init() {
            self.keychain = MockKeychain()
            self.notificationCenter = MockNotificationCenter()
            self.securityService = MockSecurityService()
            self.encoder = JSONEncoder()
            self.decoder = JSONDecoder()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            keychain.reset()
            notificationCenter.reset()
            securityService.reset()
        }
        
        /// Create test credentials storage
        func createStorage() -> CredentialsStorage {
            CredentialsStorage(
                keychain: keychain,
                notificationCenter: notificationCenter,
                securityService: securityService,
                encoder: encoder,
                decoder: decoder
            )
        }
    }
    
    // MARK: - Storage Tests
    
    @Test("Store and retrieve credentials", tags: ["storage", "credentials"])
    func testCredentialsStorage() throws {
        // Given: Storage and test credentials
        let context = TestContext()
        let storage = context.createStorage()
        let repository = MockData.Repository.validRepository
        let credentials = MockData.Repository.validCredentials
        
        // When: Storing credentials
        try storage.store(credentials, for: repository)
        
        // Then: Credentials are stored and can be retrieved
        let retrieved = try storage.get(for: repository)
        #expect(retrieved == credentials)
        #expect(context.keychain.addCalled)
        #expect(!context.securityService.showError)
    }
    
    @Test("Handle invalid credentials", tags: ["storage", "error"])
    func testInvalidCredentials() throws {
        // Given: Storage with failing keychain
        let context = TestContext()
        let storage = context.createStorage()
        let repository = MockData.Repository.validRepository
        
        context.keychain.shouldFail = true
        context.keychain.error = MockData.Error.credentialsError
        
        // When/Then: Storing invalid credentials fails
        #expect(throws: MockData.Error.credentialsError) {
            try storage.store(MockData.Repository.invalidCredentials, for: repository)
        }
        
        #expect(context.securityService.showError)
    }
    
    @Test("Update existing credentials", tags: ["storage", "update"])
    func testCredentialsUpdate() throws {
        // Given: Storage with existing credentials
        let context = TestContext()
        let storage = context.createStorage()
        let repository = MockData.Repository.validRepository
        let oldCredentials = MockData.Repository.validCredentials
        let newCredentials = MockData.Repository.updatedCredentials
        
        try storage.store(oldCredentials, for: repository)
        
        // When: Updating credentials
        try storage.update(newCredentials, for: repository)
        
        // Then: New credentials are stored
        let retrieved = try storage.get(for: repository)
        #expect(retrieved == newCredentials)
        #expect(context.keychain.updateCalled)
        #expect(!context.securityService.showError)
    }
    
    @Test("Delete credentials", tags: ["storage", "delete"])
    func testCredentialsDeletion() throws {
        // Given: Storage with stored credentials
        let context = TestContext()
        let storage = context.createStorage()
        let repository = MockData.Repository.validRepository
        let credentials = MockData.Repository.validCredentials
        
        try storage.store(credentials, for: repository)
        
        // When: Deleting credentials
        try storage.delete(for: repository)
        
        // Then: Credentials are removed
        #expect(context.keychain.deleteCalled)
        #expect(!context.securityService.showError)
        #expect(throws: MockData.Error.credentialsNotFound) {
            _ = try storage.get(for: repository)
        }
    }
    
    @Test("Handle credentials migration", tags: ["storage", "migration"])
    func testCredentialsMigration() throws {
        // Given: Storage with legacy credentials
        let context = TestContext()
        let storage = context.createStorage()
        let repository = MockData.Repository.validRepository
        let legacyCredentials = MockData.Repository.legacyCredentials
        
        context.keychain.hasLegacyData = true
        context.keychain.legacyCredentials = legacyCredentials
        
        // When: Migrating credentials
        try storage.migrate(for: repository)
        
        // Then: Credentials are migrated successfully
        let migrated = try storage.get(for: repository)
        #expect(migrated == MockData.Repository.validCredentials)
        #expect(context.keychain.migrationCalled)
        #expect(!context.securityService.showError)
    }
    
    // MARK: - Validation Tests
    
    @Test("Test credentials validation", tags: ["validation", "credentials"])
    func testCredentialsValidation() throws {
        // Given: Credentials storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Credentials.validationData
        
        // Test validation
        for testCase in testCases {
            do {
                // Validate credentials
                try storage.validate(testCase.credentials)
                
                if !testCase.expectedValid {
                    throw TestFailure("Expected validation error for invalid data")
                }
            } catch {
                if testCase.expectedValid {
                    throw TestFailure("Unexpected validation error: \(error)")
                }
                
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .credentialsValidationError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Security Tests
    
    @Test("Test credentials security", tags: ["security", "credentials"])
    func testCredentialsSecurity() throws {
        // Given: Credentials storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Credentials.securityData
        
        // Test security measures
        for testCase in testCases {
            // Store credentials
            try storage.store(testCase.credentials)
            
            // Verify security
            #expect(context.securityService.validatePasswordCalled)
            #expect(context.keychain.useAccessControlCalled)
            
            // Verify password handling
            let storedPassword = try context.keychain.getPassword(for: testCase.credentials.id)
            #expect(storedPassword != testCase.credentials.password) // Should be encrypted
            
            // Verify access control
            let accessControl = context.keychain.lastAccessControl
            #expect(accessControl?.contains(.userPresence) == true)
            
            context.reset()
        }
    }
    
    // MARK: - Migration Tests
    
    @Test("Test credentials migration", tags: ["migration", "credentials"])
    func testCredentialsMigration() throws {
        // Given: Credentials storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Credentials.migrationData
        
        // Test migration
        for testCase in testCases {
            // Setup old data
            context.keychain.mockData = testCase.oldData
            
            // Perform migration
            try storage.migrate()
            
            // Verify migration
            let migratedData = context.keychain.lastSavedData
            #expect(migratedData == testCase.expectedData)
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test credentials error handling", tags: ["error", "credentials"])
    func testErrorHandling() throws {
        // Given: Credentials storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let errorCases = MockData.Credentials.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                // Simulate error condition
                context.keychain.simulateError = errorCase.error
                
                // Attempt operation
                try errorCase.operation(storage)
                
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Verify error handling
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .credentialsStorageError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test credentials performance", tags: ["performance", "credentials"])
    func testPerformance() throws {
        // Given: Credentials storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let startTime = Date()
        
        // Perform multiple operations
        for i in 0..<100 {
            let credentials = RepositoryCredentials(
                id: UUID(),
                repositoryId: UUID(),
                username: "test-user-\(i)",
                password: "test-password-\(i)"
            )
            try storage.store(credentials)
            _ = try storage.load(credentials.id)
            try storage.delete(credentials.id)
        }
        
        let endTime = Date()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 5.0) // Should complete in under 5 seconds
        
        // Test individual operation performance
        let credentials = RepositoryCredentials(
            id: UUID(),
            repositoryId: UUID(),
            username: "test-user",
            password: "test-password"
        )
        
        let operationStart = Date()
        try storage.store(credentials)
        _ = try storage.load(credentials.id)
        try storage.delete(credentials.id)
        let operationEnd = Date()
        
        let operationInterval = operationEnd.timeIntervalSince(operationStart)
        #expect(operationInterval < 0.1) // Individual operations should be fast
    }
}
