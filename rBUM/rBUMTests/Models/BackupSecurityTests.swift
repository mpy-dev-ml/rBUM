import Foundation
import Testing
@testable import rBUM

/// Tests for BackupSecurity functionality
struct BackupSecurityTests {
    // MARK: - Test Context
    
    /// Type aliases for mock implementations
    private typealias TestMocks = TestMocksModule.TestMocks
    private typealias MockKeychain = TestMocks.MockKeychain
    private typealias MockSecurityService = TestMocks.MockSecurityService
    private typealias MockNotificationCenter = TestMocks.MockNotificationCenter
    private typealias MockDateProvider = TestMocks.MockDateProvider
    private typealias MockFileManager = TestMocks.MockFileManager
    
    /// Test environment with test data
    struct TestContext {
        let keychain: MockKeychain
        let securityService: MockSecurityService
        let notificationCenter: MockNotificationCenter
        let dateProvider: MockDateProvider
        let fileManager: MockFileManager
        
        init() {
            self.keychain = MockKeychain()
            self.securityService = MockSecurityService()
            self.notificationCenter = MockNotificationCenter()
            self.dateProvider = MockDateProvider()
            self.fileManager = MockFileManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            keychain.reset()
            securityService.reset()
            notificationCenter.reset()
            dateProvider.reset()
            fileManager.reset()
        }
        
        /// Create test security manager
        func createSecurityManager() -> BackupSecurityManager {
            BackupSecurityManager(
                keychain: keychain,
                securityService: securityService,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider,
                fileManager: fileManager
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize security manager", ["init", "security"] as! TestTrait)
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating security manager
        let manager = context.createSecurityManager()
        
        // Then: Manager is properly configured
        #expect(manager.isInitialized)
        #expect(!manager.isLocked)
    }
    
    // MARK: - Credential Tests
    
    @Test("Test credential management", ["security", "credentials"] as! TestTrait)
    func testCredentialManagement() throws {
        // Given: Security manager
        let context = TestContext()
        let manager = context.createSecurityManager()
        
        let credentials = MockData.Security.validCredentials
        
        // Test credential storage
        for credential in credentials {
            try manager.storeCredential(credential)
            #expect(context.keychain.setPasswordCalled)
            #expect(context.securityService.encryptCalled)
            
            // Test credential retrieval
            let retrieved = try manager.getCredential(for: credential.id)
            #expect(retrieved == credential)
            #expect(context.keychain.getPasswordCalled)
            #expect(context.securityService.decryptCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Key Management Tests
    
    @Test("Test key management", ["security", "keys"] as! TestTrait)
    func testKeyManagement() throws {
        // Given: Security manager
        let context = TestContext()
        let manager = context.createSecurityManager()
        
        let keys = MockData.Security.validKeys
        
        // Test key operations
        for key in keys {
            // Generate key
            let generatedKey = try manager.generateKey()
            #expect(generatedKey.count > 0)
            #expect(context.securityService.generateKeyCalled)
            
            // Store key
            try manager.storeKey(key)
            #expect(context.keychain.setPasswordCalled)
            #expect(context.securityService.encryptCalled)
            
            // Verify key
            let isValid = try manager.verifyKey(key)
            #expect(isValid)
            #expect(context.securityService.verifyKeyCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Encryption Tests
    
    @Test("Test encryption operations", ["security", "encryption"] as! TestTrait)
    func testEncryptionOperations() throws {
        // Given: Security manager
        let context = TestContext()
        let manager = context.createSecurityManager()
        
        let testData = MockData.Security.encryptionData
        
        // Test encryption/decryption
        for data in testData {
            // Encrypt data
            let encrypted = try manager.encrypt(data)
            #expect(encrypted != data)
            #expect(context.securityService.encryptCalled)
            
            // Decrypt data
            let decrypted = try manager.decrypt(encrypted)
            #expect(decrypted == data)
            #expect(context.securityService.decryptCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Repository Security Tests
    
    @Test("Test repository security", ["security", "repository"] as! TestTrait)
    func testRepositorySecurity() throws {
        // Given: Security manager
        let context = TestContext()
        let manager = context.createSecurityManager()
        
        let repositories = MockData.Security.validRepositories
        
        // Test repository security
        for repository in repositories {
            // Initialize security
            try manager.initializeRepositorySecurity(repository)
            #expect(context.securityService.initializeSecurityCalled)
            
            // Verify security
            let isSecure = try manager.verifyRepositorySecurity(repository)
            #expect(isSecure)
            #expect(context.securityService.verifySecurityCalled)
            
            // Lock repository
            try manager.lockRepository(repository)
            #expect(context.securityService.lockCalled)
            
            // Unlock repository
            try manager.unlockRepository(repository)
            #expect(context.securityService.unlockCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Cache Security Tests
    
    @Test("Test cache security", ["security", "cache"] as! TestTrait)
    func testCacheSecurity() throws {
        // Given: Security manager
        let context = TestContext()
        let manager = context.createSecurityManager()
        
        let cacheData = MockData.Security.cacheData
        
        // Test cache security
        for data in cacheData {
            // Secure cache
            try manager.secureCacheData(data)
            #expect(context.securityService.encryptCalled)
            #expect(context.fileManager.writeDataCalled)
            
            // Read secure cache
            let retrieved = try manager.readSecureCacheData()
            #expect(retrieved == data)
            #expect(context.fileManager.readDataCalled)
            #expect(context.securityService.decryptCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test security error handling", ["security", "error"] as! TestTrait)
    func testErrorHandling() throws {
        // Given: Security manager
        let context = TestContext()
        let manager = context.createSecurityManager()
        
        let errorCases = MockData.Security.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                try manager.handleSecurityOperation(errorCase)
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Expected error
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .backupSecurityError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle security edge cases", ["security", "edge"] as! TestTrait)
    func testEdgeCases() throws {
        // Given: Security manager
        let context = TestContext()
        let manager = context.createSecurityManager()
        
        // Test invalid credentials
        do {
            try manager.getCredential(for: UUID())
            throw TestFailure("Expected error for invalid credential ID")
        } catch {
            // Expected error
        }
        
        // Test empty key
        do {
            try manager.verifyKey("")
            throw TestFailure("Expected error for empty key")
        } catch {
            // Expected error
        }
        
        // Test concurrent operations
        do {
            let repository = MockData.Security.validRepositories[0]
            try manager.lockRepository(repository)
            try manager.lockRepository(repository)
            throw TestFailure("Expected error for concurrent lock")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test security performance", ["security", "performance"] as! TestTrait)
    func testPerformance() throws {
        // Given: Security manager
        let context = TestContext()
        let manager = context.createSecurityManager()
        
        // Test encryption performance
        let startTime = context.dateProvider.now()
        let testData = "Test data for performance measurement".data(using: .utf8)!
        
        for _ in 0..<1000 {
            _ = try manager.encrypt(testData)
        }
        
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test key generation performance
        let keyStartTime = context.dateProvider.now()
        
        for _ in 0..<100 {
            _ = try manager.generateKey()
        }
        
        let keyEndTime = context.dateProvider.now()
        
        let keyInterval = keyEndTime.timeIntervalSince(keyStartTime)
        #expect(keyInterval < 0.5) // Key generation should be relatively fast
    }
}
