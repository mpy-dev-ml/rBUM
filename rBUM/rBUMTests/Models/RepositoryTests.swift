import Testing
@testable import rBUM

/// Tests for Repository functionality
struct RepositoryTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let resticService: TestMocks.MockResticService
        let notificationCenter: TestMocks.MockNotificationCenter
        let dateProvider: TestMocks.MockDateProvider
        let fileManager: TestMocks.MockFileManager
        let securityService: TestMocks.MockSecurityService
        let keychain: TestMocks.MockKeychain
        
        init() {
            self.resticService = TestMocks.MockResticService()
            self.notificationCenter = TestMocks.MockNotificationCenter()
            self.dateProvider = TestMocks.MockDateProvider()
            self.fileManager = TestMocks.MockFileManager()
            self.securityService = TestMocks.MockSecurityService()
            self.keychain = TestMocks.MockKeychain()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            resticService.reset()
            notificationCenter.reset()
            dateProvider.reset()
            fileManager.reset()
            securityService.reset()
            keychain.reset()
        }
        
        /// Create test repository manager
        func createRepositoryManager() -> RepositoryManager {
            RepositoryManager(
                resticService: resticService,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider,
                fileManager: fileManager,
                securityService: securityService,
                keychain: keychain
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize repository manager", tags: ["init", "repository"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating repository manager
        let manager = context.createRepositoryManager()
        
        // Then: Manager is properly configured
        #expect(manager.isInitialized)
        #expect(manager.repositoryCount == 0)
    }
    
    // MARK: - Repository Creation Tests
    
    @Test("Test repository creation", tags: ["repository", "create"])
    func testRepositoryCreation() throws {
        // Given: Repository manager
        let context = TestContext()
        let manager = context.createRepositoryManager()
        
        let testData = MockData.Repository.creationData
        
        // Test repository creation
        for data in testData {
            // Create repository
            let repository = try manager.createRepository(data)
            #expect(repository.id != nil)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify repository
            let verified = try manager.verifyRepository(repository)
            #expect(verified)
            #expect(context.resticService.verifyRepositoryCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Repository Initialization Tests
    
    @Test("Test repository initialization", tags: ["repository", "init"])
    func testRepositoryInitialization() throws {
        // Given: Repository manager
        let context = TestContext()
        let manager = context.createRepositoryManager()
        
        let testCases = MockData.Repository.initializationData
        
        // Test repository initialization
        for testCase in testCases {
            // Initialize repository
            try manager.initializeRepository(testCase.repository)
            #expect(context.resticService.initializeRepositoryCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify initialization
            let initialized = try manager.isRepositoryInitialized(testCase.repository)
            #expect(initialized == testCase.expectedInitialized)
            
            context.reset()
        }
    }
    
    // MARK: - Repository Access Tests
    
    @Test("Test repository access", tags: ["repository", "access"])
    func testRepositoryAccess() throws {
        // Given: Repository manager
        let context = TestContext()
        let manager = context.createRepositoryManager()
        
        let testCases = MockData.Repository.accessData
        
        // Test repository access
        for testCase in testCases {
            // Set up repository
            let repository = try manager.createRepository(testCase.repository)
            
            // Test access
            let accessible = try manager.isRepositoryAccessible(repository)
            #expect(accessible == testCase.expectedAccessible)
            #expect(context.resticService.checkAccessCalled)
            
            if !accessible {
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .repositoryAccessError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Repository Update Tests
    
    @Test("Test repository updates", tags: ["repository", "update"])
    func testRepositoryUpdates() throws {
        // Given: Repository manager
        let context = TestContext()
        let manager = context.createRepositoryManager()
        
        let testCases = MockData.Repository.updateData
        
        // Test repository updates
        for testCase in testCases {
            // Create initial repository
            let repository = try manager.createRepository(testCase.initial)
            
            // Update repository
            let updated = try manager.updateRepository(repository, with: testCase.updates)
            #expect(updated.id == repository.id)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify updates
            for (key, value) in testCase.updates {
                #expect(updated.getValue(for: key) == value)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Repository Deletion Tests
    
    @Test("Test repository deletion", tags: ["repository", "delete"])
    func testRepositoryDeletion() throws {
        // Given: Repository manager
        let context = TestContext()
        let manager = context.createRepositoryManager()
        
        let testCases = MockData.Repository.deletionData
        
        // Test repository deletion
        for testCase in testCases {
            // Create repository
            let repository = try manager.createRepository(testCase.repository)
            
            // Delete repository
            try manager.deleteRepository(repository)
            #expect(context.resticService.deleteRepositoryCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify deletion
            let exists = try manager.repositoryExists(repository)
            #expect(!exists)
            
            context.reset()
        }
    }
    
    // MARK: - Repository Lock Tests
    
    @Test("Test repository locking", tags: ["repository", "lock"])
    func testRepositoryLocking() throws {
        // Given: Repository manager
        let context = TestContext()
        let manager = context.createRepositoryManager()
        
        let testCases = MockData.Repository.lockData
        
        // Test repository locking
        for testCase in testCases {
            // Create repository
            let repository = try manager.createRepository(testCase.repository)
            
            // Lock repository
            try manager.lockRepository(repository)
            #expect(context.resticService.lockRepositoryCalled)
            
            // Check lock status
            let locked = try manager.isRepositoryLocked(repository)
            #expect(locked)
            
            // Unlock repository
            try manager.unlockRepository(repository)
            #expect(context.resticService.unlockRepositoryCalled)
            
            // Verify unlock
            let stillLocked = try manager.isRepositoryLocked(repository)
            #expect(!stillLocked)
            
            context.reset()
        }
    }
    
    // MARK: - Repository Validation Tests
    
    @Test("Test repository validation", tags: ["repository", "validate"])
    func testRepositoryValidation() throws {
        // Given: Repository manager
        let context = TestContext()
        let manager = context.createRepositoryManager()
        
        let testCases = MockData.Repository.validationData
        
        // Test repository validation
        for testCase in testCases {
            // Validate repository
            let isValid = try manager.validateRepository(testCase.repository)
            #expect(isValid == testCase.expectedValid)
            
            if !isValid {
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .repositoryValidationError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test repository error handling", tags: ["repository", "error"])
    func testErrorHandling() throws {
        // Given: Repository manager
        let context = TestContext()
        let manager = context.createRepositoryManager()
        
        let errorCases = MockData.Repository.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                try manager.handleRepositoryOperation(errorCase)
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Expected error
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .repositoryError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle repository edge cases", tags: ["repository", "edge"])
    func testEdgeCases() throws {
        // Given: Repository manager
        let context = TestContext()
        let manager = context.createRepositoryManager()
        
        // Test invalid repository
        do {
            try manager.verifyRepository(BackupRepository(id: "invalid"))
            throw TestFailure("Expected error for invalid repository")
        } catch {
            // Expected error
        }
        
        // Test duplicate repository
        do {
            let repository = try manager.createRepository(name: "test")
            try manager.addRepository(repository)
            try manager.addRepository(repository)
            throw TestFailure("Expected error for duplicate repository")
        } catch {
            // Expected error
        }
        
        // Test corrupted repository
        do {
            let repository = try manager.createRepository(name: "corrupted")
            context.resticService.simulateCorruption = true
            try manager.verifyRepository(repository)
            throw TestFailure("Expected error for corrupted repository")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test repository performance", tags: ["repository", "performance"])
    func testPerformance() throws {
        // Given: Repository manager
        let context = TestContext()
        let manager = context.createRepositoryManager()
        
        // Test initialization performance
        let startTime = context.dateProvider.now()
        let testRepository = try manager.createRepository(MockData.Repository.initializationData[0].repository)
        
        for _ in 0..<10 {
            try manager.initializeRepository(testRepository)
        }
        
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 5.0) // Should complete in under 5 seconds
        
        // Test validation performance
        let validationStartTime = context.dateProvider.now()
        
        for _ in 0..<100 {
            _ = try manager.validateRepository(testRepository)
        }
        
        let validationEndTime = context.dateProvider.now()
        
        let validationInterval = validationEndTime.timeIntervalSince(validationStartTime)
        #expect(validationInterval < 1.0) // Validation should be fast
    }
}
