//
//  BackupResticTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM
import TestMocksModule

/// Tests for BackupRestic functionality
struct BackupResticTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let fileManager: TestMocksModule.TestMocks.MockFileManager
        let processManager: TestMocksModule.TestMocks.MockProcessManager
        let keychain: TestMocksModule.TestMocks.MockKeychain
        let notificationCenter: TestMocksModule.TestMocks.MockNotificationCenter
        let dateProvider: TestMocksModule.TestMocks.MockDateProvider
        
        init() {
            self.fileManager = TestMocksModule.TestMocks.MockFileManager()
            self.processManager = TestMocksModule.TestMocks.MockProcessManager()
            self.keychain = TestMocksModule.TestMocks.MockKeychain()
            self.notificationCenter = TestMocksModule.TestMocks.MockNotificationCenter()
            self.dateProvider = TestMocksModule.TestMocks.MockDateProvider()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            fileManager.reset()
            processManager.reset()
            keychain.reset()
            notificationCenter.reset()
            dateProvider.reset()
        }
        
        /// Create test restic manager
        func createResticManager() -> BackupResticManager {
            BackupResticManager(
                fileManager: fileManager,
                processManager: processManager,
                keychain: keychain,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize restic manager", tags: ["init", "restic"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating restic manager
        let manager = context.createResticManager()
        
        // Then: Manager is properly configured
        #expect(manager.isInstalled)
        #expect(manager.version != nil)
        #expect(!manager.isRunning)
    }
    
    // MARK: - Repository Tests
    
    @Test("Test repository operations", tags: ["restic", "repository"])
    func testRepositoryOperations() throws {
        // Given: Restic manager
        let context = TestContext()
        let manager = context.createResticManager()
        
        let repositories = MockData.Restic.validRepositories
        
        // Test repository initialization
        for repo in repositories {
            try manager.initRepository(repo)
            #expect(context.processManager.runProcessCalled)
            #expect(context.keychain.setPasswordCalled)
            
            context.reset()
        }
        
        // Test repository checks
        for repo in repositories {
            try manager.checkRepository(repo)
            #expect(context.processManager.runProcessCalled)
            let args = context.processManager.lastProcessArgs
            #expect(args.contains("check"))
            
            context.reset()
        }
    }
    
    // MARK: - Backup Tests
    
    @Test("Test backup operations", tags: ["restic", "backup"])
    func testBackupOperations() throws {
        // Given: Restic manager
        let context = TestContext()
        let manager = context.createResticManager()
        
        let backups = MockData.Restic.validBackups
        
        // Test backup creation
        for backup in backups {
            try manager.createBackup(backup)
            #expect(context.processManager.runProcessCalled)
            let args = context.processManager.lastProcessArgs
            #expect(args.contains("backup"))
            
            context.reset()
        }
        
        // Test backup verification
        for backup in backups {
            try manager.verifyBackup(backup)
            #expect(context.processManager.runProcessCalled)
            let args = context.processManager.lastProcessArgs
            #expect(args.contains("verify"))
            
            context.reset()
        }
    }
    
    // MARK: - Restore Tests
    
    @Test("Test restore operations", tags: ["restic", "restore"])
    func testRestoreOperations() throws {
        // Given: Restic manager
        let context = TestContext()
        let manager = context.createResticManager()
        
        let restores = MockData.Restic.validRestores
        
        // Test restore operations
        for restore in restores {
            try manager.restore(restore)
            #expect(context.processManager.runProcessCalled)
            let args = context.processManager.lastProcessArgs
            #expect(args.contains("restore"))
            
            context.reset()
        }
    }
    
    // MARK: - Snapshot Tests
    
    @Test("Test snapshot operations", tags: ["restic", "snapshot"])
    func testSnapshotOperations() throws {
        // Given: Restic manager
        let context = TestContext()
        let manager = context.createResticManager()
        
        let snapshots = MockData.Restic.validSnapshots
        
        // Test snapshot listing
        let repository = MockData.Restic.validRepositories[0]
        try manager.listSnapshots(repository)
        #expect(context.processManager.runProcessCalled)
        let args = context.processManager.lastProcessArgs
        #expect(args.contains("snapshots"))
        
        context.reset()
        
        // Test snapshot operations
        for snapshot in snapshots {
            // Test checking snapshot
            try manager.checkSnapshot(snapshot)
            #expect(context.processManager.runProcessCalled)
            
            context.reset()
            
            // Test removing snapshot
            try manager.removeSnapshot(snapshot)
            #expect(context.processManager.runProcessCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Process Management Tests
    
    @Test("Test process management", tags: ["restic", "process"])
    func testProcessManagement() throws {
        // Given: Restic manager
        let context = TestContext()
        let manager = context.createResticManager()
        
        let operations = MockData.Restic.processOperations
        
        // Test process handling
        for operation in operations {
            // Start process
            try manager.startOperation(operation)
            #expect(manager.isRunning)
            #expect(context.processManager.runProcessCalled)
            
            // Test process output
            let output = "Progress: 50%"
            context.processManager.simulateOutput(output)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Test process completion
            context.processManager.simulateCompletion(0)
            #expect(!manager.isRunning)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test error handling", tags: ["restic", "error"])
    func testErrorHandling() throws {
        // Given: Restic manager
        let context = TestContext()
        let manager = context.createResticManager()
        
        let operations = MockData.Restic.errorOperations
        
        // Test error handling
        for operation in operations {
            do {
                try manager.startOperation(operation)
                
                // Simulate error
                let error = "Error: repository locked"
                context.processManager.simulateError(error)
                
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .backupError)
                
            } catch {
                // Expected error
            }
            
            context.reset()
        }
    }
    
    // MARK: - Configuration Tests
    
    @Test("Test restic configuration", tags: ["restic", "config"])
    func testConfiguration() throws {
        // Given: Restic manager
        let context = TestContext()
        let manager = context.createResticManager()
        
        let configs = MockData.Restic.validConfigs
        
        // Test configuration handling
        for config in configs {
            try manager.applyConfiguration(config)
            #expect(context.processManager.runProcessCalled)
            
            // Verify environment variables
            let env = context.processManager.lastProcessEnv
            #expect(env["RESTIC_PASSWORD"] != nil)
            #expect(env["RESTIC_REPOSITORY"] != nil)
            
            context.reset()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle restic edge cases", tags: ["restic", "edge"])
    func testEdgeCases() throws {
        // Given: Restic manager
        let context = TestContext()
        let manager = context.createResticManager()
        
        // Test invalid repository path
        do {
            try manager.initRepository(MockData.Restic.invalidRepository)
            throw TestFailure("Expected error for invalid repository")
        } catch {
            // Expected error
        }
        
        // Test missing password
        do {
            context.keychain.simulatePasswordMissing()
            try manager.createBackup(MockData.Restic.validBackups[0])
            throw TestFailure("Expected error for missing password")
        } catch {
            // Expected error
        }
        
        // Test concurrent operations
        do {
            let operation = MockData.Restic.processOperations[0]
            try manager.startOperation(operation)
            try manager.startOperation(operation)
            throw TestFailure("Expected error for concurrent operations")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test restic performance", tags: ["restic", "performance"])
    func testPerformance() throws {
        // Given: Restic manager
        let context = TestContext()
        let manager = context.createResticManager()
        
        // Test command generation performance
        let startTime = context.dateProvider.now()
        for _ in 0..<1000 {
            _ = try manager.buildCommand(["backup", "/test"])
        }
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test environment setup performance
        let setupStartTime = context.dateProvider.now()
        for _ in 0..<1000 {
            _ = try manager.prepareEnvironment(MockData.Restic.validConfigs[0])
        }
        let setupEndTime = context.dateProvider.now()
        
        let setupInterval = setupEndTime.timeIntervalSince(setupStartTime)
        #expect(setupInterval < 0.1) // Environment setup should be fast
    }
}

// MARK: - Mock Process Manager

/// Mock implementation of ProcessManager for testing
final class MockProcessManager: ProcessManagerProtocol {
    private(set) var runProcessCalled = false
    private(set) var lastProcessArgs: [String] = []
    private(set) var lastProcessEnv: [String: String] = [:]
    private var outputHandler: ((String) -> Void)?
    private var completionHandler: ((Int32) -> Void)?
    
    func runProcess(_ args: [String], environment: [String: String]?, output: @escaping (String) -> Void, completion: @escaping (Int32) -> Void) throws {
        runProcessCalled = true
        lastProcessArgs = args
        lastProcessEnv = environment ?? [:]
        outputHandler = output
        completionHandler = completion
    }
    
    func simulateOutput(_ output: String) {
        outputHandler?(output)
    }
    
    func simulateError(_ error: String) {
        outputHandler?(error)
        completionHandler?(1)
    }
    
    func simulateCompletion(_ exitCode: Int32) {
        completionHandler?(exitCode)
    }
    
    func reset() {
        runProcessCalled = false
        lastProcessArgs = []
        lastProcessEnv = [:]
        outputHandler = nil
        completionHandler = nil
    }
}

// MARK: - Mock Keychain

/// Mock implementation of Keychain for testing
final class MockKeychain: KeychainProtocol {
    private(set) var setPasswordCalled = false
    private(set) var getPasswordCalled = false
    private var shouldSimulatePasswordMissing = false
    
    func setPassword(_ password: String, for service: String) throws {
        setPasswordCalled = true
    }
    
    func getPassword(for service: String) throws -> String {
        getPasswordCalled = true
        if shouldSimulatePasswordMissing {
            throw KeychainError.itemNotFound
        }
        return "test-password"
    }
    
    func simulatePasswordMissing() {
        shouldSimulatePasswordMissing = true
    }
    
    func reset() {
        setPasswordCalled = false
        getPasswordCalled = false
        shouldSimulatePasswordMissing = false
    }
}
