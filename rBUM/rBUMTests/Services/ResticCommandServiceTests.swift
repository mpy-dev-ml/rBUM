import Testing
@testable import rBUM

/// Tests for ResticCommandService functionality
struct ResticCommandServiceTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let processRunner: MockProcessRunner
        let notificationCenter: MockNotificationCenter
        let fileManager: MockFileManager
        let securityService: MockSecurityService
        let keychain: MockKeychain
        let progressTracker: MockProgressTracker
        
        init() {
            self.processRunner = MockProcessRunner()
            self.notificationCenter = MockNotificationCenter()
            self.fileManager = MockFileManager()
            self.securityService = MockSecurityService()
            self.keychain = MockKeychain()
            self.progressTracker = MockProgressTracker()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            processRunner.reset()
            notificationCenter.reset()
            fileManager.reset()
            securityService.reset()
            keychain.reset()
            progressTracker.reset()
        }
        
        /// Create test restic command service
        func createService() -> ResticCommandService {
            ResticCommandService(
                processRunner: processRunner,
                notificationCenter: notificationCenter,
                fileManager: fileManager,
                securityService: securityService,
                keychain: keychain,
                progressTracker: progressTracker
            )
        }
    }
    
    // MARK: - Command Execution Tests
    
    @Test("Test basic command execution", tags: ["command", "execute"])
    func testBasicCommandExecution() throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Restic.commandData
        
        // Test command execution
        for testCase in testCases {
            // Execute command
            let result = try service.execute(testCase.command)
            
            // Verify execution
            #expect(context.processRunner.runCalled)
            #expect(context.processRunner.lastCommand == testCase.expectedCommand)
            #expect(result == testCase.expectedOutput)
            
            context.reset()
        }
    }
    
    // MARK: - Repository Operations Tests
    
    @Test("Test repository operations", tags: ["repository", "operations"])
    func testRepositoryOperations() throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Restic.repositoryData
        
        // Test repository operations
        for testCase in testCases {
            // Execute operation
            try service.executeRepositoryOperation(
                testCase.operation,
                repository: testCase.repository
            )
            
            // Verify operation
            #expect(context.processRunner.runCalled)
            #expect(context.processRunner.lastCommand.contains(testCase.expectedCommandPart))
            #expect(context.keychain.getPasswordCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Backup Operations Tests
    
    @Test("Test backup operations", tags: ["backup", "operations"])
    func testBackupOperations() throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Restic.backupData
        
        // Test backup operations
        for testCase in testCases {
            // Execute backup
            try service.executeBackup(
                testCase.backup,
                repository: testCase.repository
            )
            
            // Verify backup
            #expect(context.processRunner.runCalled)
            #expect(context.processRunner.lastCommand.contains("backup"))
            #expect(context.progressTracker.updateProgressCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Restore Operations Tests
    
    @Test("Test restore operations", tags: ["restore", "operations"])
    func testRestoreOperations() throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Restic.restoreData
        
        // Test restore operations
        for testCase in testCases {
            // Execute restore
            try service.executeRestore(
                testCase.restore,
                repository: testCase.repository
            )
            
            // Verify restore
            #expect(context.processRunner.runCalled)
            #expect(context.processRunner.lastCommand.contains("restore"))
            #expect(context.progressTracker.updateProgressCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Progress Tracking Tests
    
    @Test("Test progress tracking", tags: ["progress", "tracking"])
    func testProgressTracking() throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Restic.progressData
        
        // Test progress tracking
        for testCase in testCases {
            // Execute operation with progress
            try service.executeWithProgress(
                testCase.command,
                operation: testCase.operation
            )
            
            // Verify progress tracking
            #expect(context.progressTracker.startProgressCalled)
            #expect(context.progressTracker.updateProgressCalled)
            #expect(context.progressTracker.completeProgressCalled)
            
            let progress = context.progressTracker.lastProgress
            #expect(progress >= 0 && progress <= 1.0)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test error handling", tags: ["error", "handling"])
    func testErrorHandling() throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let errorCases = MockData.Restic.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                // Simulate error condition
                context.processRunner.simulateError = errorCase.error
                
                // Attempt operation
                try service.execute(errorCase.command)
                
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Verify error handling
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .resticCommandError)
                
                // Verify error logging
                #expect(!context.processRunner.lastCommand.contains(errorCase.sensitiveData))
            }
            
            context.reset()
        }
    }
    
    // MARK: - Security Tests
    
    @Test("Test command security", tags: ["security", "command"])
    func testCommandSecurity() throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Restic.securityData
        
        // Test command security
        for testCase in testCases {
            // Execute secure command
            try service.executeSecure(
                testCase.command,
                credentials: testCase.credentials
            )
            
            // Verify security measures
            #expect(!context.processRunner.lastCommand.contains(testCase.credentials.password))
            #expect(context.securityService.validateCredentialsCalled)
            
            // Verify process environment
            let env = context.processRunner.lastEnvironment
            #expect(!env.contains { $0.value.contains(testCase.credentials.password) })
            
            context.reset()
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test command performance", tags: ["performance", "command"])
    func testPerformance() throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let startTime = Date()
        
        // Execute multiple commands
        for i in 0..<100 {
            _ = try service.execute(["version"])
        }
        
        let endTime = Date()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 5.0) // Should complete in under 5 seconds
        
        // Test individual command performance
        let commandStart = Date()
        _ = try service.execute(["version"])
        let commandEnd = Date()
        
        let commandInterval = commandEnd.timeIntervalSince(commandStart)
        #expect(commandInterval < 0.1) // Individual commands should be fast
    }
    
    // MARK: - JSON Output Tests
    
    @Test("Test JSON output parsing", tags: ["json", "parsing"])
    func testJSONOutputParsing() throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Restic.jsonOutputData
        
        // Test JSON output parsing
        for testCase in testCases {
            // When: Executing command with JSON output
            let result = try service.executeWithJSONOutput(testCase.command)
            
            // Then: Verify JSON parsing
            #expect(context.processRunner.runCalled)
            #expect(context.processRunner.lastCommand.contains("--json"))
            #expect(result.isValidJSON)
            #expect(result == testCase.expectedJSON)
            
            context.reset()
        }
    }
    
    // MARK: - Repository Locking Tests
    
    @Test("Test repository locking and concurrent access", tags: ["locking", "concurrent"])
    func testRepositoryLocking() async throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let repository = MockData.Restic.testRepository
        
        // When: Acquiring lock
        let lock = try await service.acquireLock(repository)
        
        // Then: Lock is acquired
        #expect(context.processRunner.runCalled)
        #expect(context.processRunner.lastCommand.contains("lock"))
        #expect(lock != nil)
        
        // When: Attempting concurrent access
        let concurrentResult = try await service.acquireLock(repository)
        
        // Then: Concurrent access is prevented
        #expect(concurrentResult == nil)
        
        // When: Releasing lock
        try await service.releaseLock(lock!)
        
        // Then: Lock is released
        #expect(context.processRunner.lastCommand.contains("unlock"))
    }
    
    // MARK: - Network Tests
    
    @Test("Test network timeout handling", tags: ["network", "timeout"])
    func testNetworkTimeouts() async throws {
        // Given: Restic command service with timeout configuration
        let context = TestContext()
        let service = context.createService()
        
        context.processRunner.simulateNetworkTimeout = true
        
        // When: Executing command with timeout
        do {
            _ = try await service.executeWithTimeout(MockData.Restic.longRunningCommand)
            XCTFail("Should have thrown timeout error")
        } catch {
            // Then: Timeout error is thrown
            #expect(error is ResticError)
            #expect((error as? ResticError)?.isTimeout == true)
        }
        
        // Verify timeout handling
        #expect(context.processRunner.runCalled)
        #expect(context.processRunner.lastCommand.contains("--timeout"))
        #expect(context.notificationCenter.postCalled)
    }
    
    // MARK: - Large Backup Tests
    
    @Test("Test large backup handling", tags: ["backup", "performance"])
    func testLargeBackupHandling() async throws {
        // Given: Restic command service
        let context = TestContext()
        let service = context.createService()
        
        let largeBackup = MockData.Restic.largeBackupData
        
        // When: Starting large backup
        try await service.startBackup(largeBackup)
        
        // Then: Verify chunking and progress tracking
        #expect(context.processRunner.runCalled)
        #expect(context.processRunner.lastCommand.contains("--pack-size"))
        #expect(context.progressTracker.updateProgressCalled)
        
        // Verify memory usage stays within bounds
        #expect(context.processRunner.peakMemoryUsage < 512_000_000) // 512MB limit
        
        // Verify backup completion
        let status = try await service.getBackupStatus(largeBackup.id)
        #expect(status.isComplete)
        #expect(!status.hasErrors)
    }
}
