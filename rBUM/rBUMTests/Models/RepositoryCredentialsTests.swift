//
//  RepositoryCredentialsTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for RepositoryCredentials functionality
struct RepositoryCredentialsTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let keychain: MockKeychain
        let notificationCenter: MockNotificationCenter
        let dateProvider: MockDateProvider
        let securityService: MockSecurityService
        
        init() {
            self.keychain = MockKeychain()
            self.notificationCenter = MockNotificationCenter()
            self.dateProvider = MockDateProvider()
            self.securityService = MockSecurityService()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            keychain.reset()
            notificationCenter.reset()
            dateProvider.reset()
            securityService.reset()
        }
        
        /// Create test credentials manager
        func createCredentialsManager() -> RepositoryCredentialsManager {
            RepositoryCredentialsManager(
                keychain: keychain,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider,
                securityService: securityService
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize credentials manager", tags: ["init", "credentials"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating credentials manager
        let manager = context.createCredentialsManager()
        
        // Then: Manager is properly configured
        #expect(manager.isInitialized)
        #expect(manager.credentialsCount == 0)
    }
    
    // MARK: - Credentials Storage Tests
    
    @Test("Test credentials storage", tags: ["credentials", "storage"])
    func testCredentialsStorage() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createCredentialsManager()
        
        let testCases = MockData.Credentials.storageData
        
        // Test credentials storage
        for testCase in testCases {
            // Store credentials
            try manager.storeCredentials(testCase.credentials, for: testCase.repository)
            #expect(context.keychain.saveCredentialsCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Retrieve credentials
            let retrieved = try manager.retrieveCredentials(for: testCase.repository)
            #expect(retrieved == testCase.credentials)
            #expect(context.keychain.retrieveCredentialsCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Credentials Update Tests
    
    @Test("Test credentials updates", tags: ["credentials", "update"])
    func testCredentialsUpdates() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createCredentialsManager()
        
        let testCases = MockData.Credentials.updateData
        
        // Test credentials updates
        for testCase in testCases {
            // Store initial credentials
            try manager.storeCredentials(testCase.initial, for: testCase.repository)
            
            // Update credentials
            try manager.updateCredentials(testCase.updated, for: testCase.repository)
            #expect(context.keychain.updateCredentialsCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify updates
            let retrieved = try manager.retrieveCredentials(for: testCase.repository)
            #expect(retrieved == testCase.updated)
            
            context.reset()
        }
    }
    
    // MARK: - Credentials Deletion Tests
    
    @Test("Test credentials deletion", tags: ["credentials", "delete"])
    func testCredentialsDeletion() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createCredentialsManager()
        
        let testCases = MockData.Credentials.deletionData
        
        // Test credentials deletion
        for testCase in testCases {
            // Store credentials
            try manager.storeCredentials(testCase.credentials, for: testCase.repository)
            
            // Delete credentials
            try manager.deleteCredentials(for: testCase.repository)
            #expect(context.keychain.deleteCredentialsCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify deletion
            do {
                _ = try manager.retrieveCredentials(for: testCase.repository)
                throw TestFailure("Expected error for deleted credentials")
            } catch {
                // Expected error
            }
            
            context.reset()
        }
    }
    
    // MARK: - Credentials Validation Tests
    
    @Test("Test credentials validation", tags: ["credentials", "validate"])
    func testCredentialsValidation() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createCredentialsManager()
        
        let testCases = MockData.Credentials.validationData
        
        // Test credentials validation
        for testCase in testCases {
            // Validate credentials
            let isValid = try manager.validateCredentials(testCase.credentials)
            #expect(isValid == testCase.expectedValid)
            
            if !isValid {
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .repositoryCredentialsValidationError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Credentials Security Tests
    
    @Test("Test credentials security", tags: ["credentials", "security"])
    func testCredentialsSecurity() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createCredentialsManager()
        
        let testCases = MockData.Credentials.securityData
        
        // Test credentials security
        for testCase in testCases {
            // Encrypt credentials
            let encrypted = try manager.encryptCredentials(testCase.credentials)
            #expect(context.securityService.encryptCalled)
            
            // Decrypt credentials
            let decrypted = try manager.decryptCredentials(encrypted)
            #expect(context.securityService.decryptCalled)
            #expect(decrypted == testCase.credentials)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test credentials error handling", tags: ["credentials", "error"])
    func testErrorHandling() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createCredentialsManager()
        
        let errorCases = MockData.Credentials.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                try manager.handleCredentialsOperation(errorCase)
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Expected error
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .repositoryCredentialsError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle credentials edge cases", tags: ["credentials", "edge"])
    func testEdgeCases() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createCredentialsManager()
        
        // Test missing credentials
        do {
            _ = try manager.retrieveCredentials(for: BackupRepository(id: "invalid"))
            throw TestFailure("Expected error for missing credentials")
        } catch {
            // Expected error
        }
        
        // Test invalid credentials format
        do {
            try manager.validateCredentials(RepositoryCredentials(username: "", password: ""))
            throw TestFailure("Expected error for invalid credentials")
        } catch {
            // Expected error
        }
        
        // Test corrupted encrypted data
        do {
            _ = try manager.decryptCredentials(Data())
            throw TestFailure("Expected error for corrupted data")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test credentials performance", tags: ["credentials", "performance"])
    func testPerformance() throws {
        // Given: Credentials manager
        let context = TestContext()
        let manager = context.createCredentialsManager()
        
        // Test encryption performance
        let startTime = context.dateProvider.now()
        let testCredentials = MockData.Credentials.securityData[0].credentials
        
        for _ in 0..<100 {
            _ = try manager.encryptCredentials(testCredentials)
        }
        
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test validation performance
        let validationStartTime = context.dateProvider.now()
        
        for _ in 0..<1000 {
            _ = try manager.validateCredentials(testCredentials)
        }
        
        let validationEndTime = context.dateProvider.now()
        
        let validationInterval = validationEndTime.timeIntervalSince(validationStartTime)
        #expect(validationInterval < 0.5) // Validation should be fast
    }
}
