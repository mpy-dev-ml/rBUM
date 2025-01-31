//
//  KeychainCredentialsManagerTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for KeychainCredentialsManager functionality
struct KeychainCredentialsManagerTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let keychain: MockKeychain
        let notificationCenter: MockNotificationCenter
        let securityService: MockSecurityService
        let accessControl: MockAccessControl
        
        init() {
            self.keychain = MockKeychain()
            self.notificationCenter = MockNotificationCenter()
            self.securityService = MockSecurityService()
            self.accessControl = MockAccessControl()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            keychain.reset()
            notificationCenter.reset()
            securityService.reset()
            accessControl.reset()
        }
        
        /// Create test credentials manager
        func createManager() -> KeychainCredentialsManager {
            KeychainCredentialsManager(
                keychain: keychain,
                notificationCenter: notificationCenter,
                securityService: securityService,
                accessControl: accessControl
            )
        }
    }
    
    // MARK: - Credentials Management Tests
    
    @Test("Store and retrieve credentials", tags: ["credentials", "management"])
    func testCredentialsManagement() throws {
        // Given: Manager and test credentials
        let context = TestContext()
        let manager = context.createManager()
        let repository = MockData.Repository.validRepository
        let credentials = MockData.Repository.validCredentials
        
        // When: Storing credentials
        try manager.storeCredentials(credentials, for: repository)
        
        // Then: Credentials are stored and can be retrieved
        let retrieved = try manager.getCredentials(for: repository)
        #expect(retrieved == credentials)
        #expect(context.keychain.addCalled)
        #expect(!context.securityService.showError)
    }
    
    @Test("Handle invalid credentials", tags: ["credentials", "error"])
    func testInvalidCredentials() throws {
        // Given: Manager and invalid credentials
        let context = TestContext()
        let manager = context.createManager()
        let repository = MockData.Repository.validRepository
        
        context.keychain.shouldFail = true
        context.keychain.error = MockData.Error.credentialsError
        
        // When/Then: Storing invalid credentials fails
        #expect(throws: MockData.Error.credentialsError) {
            try manager.storeCredentials(MockData.Repository.invalidCredentials, for: repository)
        }
        
        #expect(context.securityService.showError)
    }
    
    @Test("Update existing credentials", tags: ["credentials", "update"])
    func testCredentialsUpdate() throws {
        // Given: Manager and existing credentials
        let context = TestContext()
        let manager = context.createManager()
        let repository = MockData.Repository.validRepository
        let oldCredentials = MockData.Repository.validCredentials
        let newCredentials = MockData.Repository.updatedCredentials
        
        try manager.storeCredentials(oldCredentials, for: repository)
        
        // When: Updating credentials
        try manager.updateCredentials(newCredentials, for: repository)
        
        // Then: New credentials are stored
        let retrieved = try manager.getCredentials(for: repository)
        #expect(retrieved == newCredentials)
        #expect(context.keychain.updateCalled)
        #expect(!context.securityService.showError)
    }
    
    @Test("Delete credentials", tags: ["credentials", "delete"])
    func testCredentialsDeletion() throws {
        // Given: Manager and stored credentials
        let context = TestContext()
        let manager = context.createManager()
        let repository = MockData.Repository.validRepository
        let credentials = MockData.Repository.validCredentials
        
        try manager.storeCredentials(credentials, for: repository)
        
        // When: Deleting credentials
        try manager.deleteCredentials(for: repository)
        
        // Then: Credentials are removed
        #expect(context.keychain.deleteCalled)
        #expect(!context.securityService.showError)
        #expect(throws: MockData.Error.credentialsNotFound) {
            _ = try manager.getCredentials(for: repository)
        }
    }
    
    @Test("Verify security measures", tags: ["credentials", "security"])
    func testSecurityMeasures() throws {
        // Given: Manager and test data
        let context = TestContext()
        let manager = context.createManager()
        let repository = MockData.Repository.validRepository
        let credentials = MockData.Repository.validCredentials
        
        // When: Storing credentials
        try manager.storeCredentials(credentials, for: repository)
        
        // Then: Security measures are in place
        #expect(context.accessControl.validateCalled)
        #expect(context.securityService.encryptCalled)
        #expect(!context.securityService.showError)
    }
    
    // MARK: - Access Control Tests
    
    @Test("Test access control", tags: ["access", "control"])
    func testAccessControl() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createManager()
        
        let testCases = MockData.Keychain.accessControlData
        
        // Test access control
        for testCase in testCases {
            // Configure access control
            context.accessControl.mockConfiguration = testCase.configuration
            
            // Store credentials with access control
            try manager.storeCredentials(MockData.Repository.validCredentials, for: MockData.Repository.validRepository)
            
            // Verify access control
            #expect(context.keychain.useAccessControlCalled)
            let accessControl = context.keychain.lastAccessControl
            #expect(accessControl?.contains(testCase.expectedFlags) == true)
            
            // Verify biometric authentication
            if testCase.requiresBiometrics {
                #expect(context.accessControl.biometricAuthenticationCalled)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test error handling", tags: ["error", "handling"])
    func testErrorHandling() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createManager()
        
        let errorCases = MockData.Keychain.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                // Simulate error condition
                context.keychain.simulateError = errorCase.error
                
                // Attempt operation
                try errorCase.operation(manager)
                
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Verify error handling
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .keychainError)
                
                // Verify error doesn't expose sensitive data
                let errorDescription = String(describing: error)
                #expect(!errorDescription.contains(errorCase.sensitiveData))
            }
            
            context.reset()
        }
    }
    
    // MARK: - Migration Tests
    
    @Test("Test credentials migration", tags: ["migration", "credentials"])
    func testCredentialsMigration() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createManager()
        
        let testCases = MockData.Keychain.migrationData
        
        // Test migration
        for testCase in testCases {
            // Setup old data
            context.keychain.mockData = testCase.oldData
            
            // Perform migration
            try manager.migrate()
            
            // Verify migration
            let migratedData = context.keychain.lastSavedData
            #expect(migratedData == testCase.expectedData)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify old data cleanup
            #expect(context.keychain.deletePasswordCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test credentials performance", tags: ["performance", "credentials"])
    func testPerformance() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createManager()
        
        let startTime = Date()
        
        // Perform multiple operations
        for i in 0..<100 {
            let credentials = RepositoryCredentials(
                id: UUID(),
                repositoryId: UUID(),
                username: "test-user-\(i)",
                password: "test-password-\(i)"
            )
            try manager.storeCredentials(credentials, for: MockData.Repository.validRepository)
            _ = try manager.getCredentials(for: MockData.Repository.validRepository)
            try manager.deleteCredentials(for: MockData.Repository.validRepository)
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
        try manager.storeCredentials(credentials, for: MockData.Repository.validRepository)
        _ = try manager.getCredentials(for: MockData.Repository.validRepository)
        try manager.deleteCredentials(for: MockData.Repository.validRepository)
        let operationEnd = Date()
        
        let operationInterval = operationEnd.timeIntervalSince(operationStart)
        #expect(operationInterval < 0.1) // Individual operations should be fast
    }
}
