//
//  BackupOperationTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupOperation functionality
struct BackupOperationTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let fileManager: MockFileManager
        let dateProvider: MockDateProvider
        let notificationCenter: MockNotificationCenter
        let resticService: MockResticService
        let progressTracker: MockProgressTracker
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.fileManager = MockFileManager()
            self.dateProvider = MockDateProvider()
            self.notificationCenter = MockNotificationCenter()
            self.resticService = MockResticService()
            self.progressTracker = MockProgressTracker()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            fileManager.reset()
            dateProvider.reset()
            notificationCenter.reset()
            resticService.reset()
            progressTracker.reset()
        }
        
        /// Create test operation manager
        func createOperationManager() -> BackupOperationManager {
            BackupOperationManager(
                userDefaults: userDefaults,
                fileManager: fileManager,
                dateProvider: dateProvider,
                notificationCenter: notificationCenter,
                resticService: resticService,
                progressTracker: progressTracker
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup operation manager", tags: ["init", "operation"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating operation manager
        let manager = context.createOperationManager()
        
        // Then: Manager is configured correctly
        #expect(manager.operations.isEmpty)
        #expect(manager.activeOperations.isEmpty)
        #expect(manager.maxConcurrentOperations == 1)
        #expect(!manager.isPaused)
    }
    
    // MARK: - Operation Tests
    
    @Test("Test basic operation handling", tags: ["operation", "core"])
    func testOperationHandling() throws {
        // Given: Operation manager
        let context = TestContext()
        let manager = context.createOperationManager()
        
        let operations = MockData.Operation.validOperations
        
        // Test operation creation
        for operation in operations {
            try manager.addOperation(operation)
            
            // Verify operation was added
            #expect(manager.operations.contains(operation))
            #expect(manager.getOperation(operation.id) != nil)
            
            // Verify notifications
            #expect(context.notificationCenter.postCalled)
            
            context.reset()
        }
        
        // Test operation retrieval
        let firstOperation = operations[0]
        let retrievedOperation = manager.getOperation(firstOperation.id)
        #expect(retrievedOperation == firstOperation)
        
        // Test operation removal
        try manager.removeOperation(firstOperation.id)
        #expect(!manager.operations.contains(firstOperation))
    }
    
    // MARK: - Execution Tests
    
    @Test("Test operation execution", tags: ["operation", "execution"])
    func testOperationExecution() throws {
        // Given: Operation manager
        let context = TestContext()
        let manager = context.createOperationManager()
        
        let operation = MockData.Operation.validOperations[0]
        
        // Test operation start
        try manager.addOperation(operation)
        try manager.startOperation(operation.id)
        
        #expect(manager.isOperationActive(operation.id))
        #expect(context.resticService.backupCalled)
        #expect(context.progressTracker.startCalled)
        
        // Test operation progress
        context.progressTracker.simulateProgress(0.5)
        let updatedOperation = manager.getOperation(operation.id)
        #expect(updatedOperation?.progress == 0.5)
        
        // Test operation completion
        context.progressTracker.simulateCompletion()
        #expect(!manager.isOperationActive(operation.id))
        #expect(manager.getOperation(operation.id)?.status == .completed)
    }
    
    // MARK: - Concurrency Tests
    
    @Test("Test concurrent operations", tags: ["operation", "concurrency"])
    func testConcurrency() throws {
        // Given: Operation manager with concurrency
        let context = TestContext()
        let manager = context.createOperationManager()
        manager.maxConcurrentOperations = 2
        
        let operations = Array(MockData.Operation.validOperations.prefix(3))
        
        // Add operations
        for operation in operations {
            try manager.addOperation(operation)
        }
        
        // Start first two operations
        try manager.startOperation(operations[0].id)
        try manager.startOperation(operations[1].id)
        
        // Verify concurrent execution
        #expect(manager.activeOperations.count == 2)
        
        // Try to start third operation
        do {
            try manager.startOperation(operations[2].id)
            throw TestFailure("Expected error for exceeding concurrent operations")
        } catch {
            // Expected error
        }
        
        // Complete first operation
        context.progressTracker.simulateCompletion()
        
        // Now third operation should start
        try manager.startOperation(operations[2].id)
        #expect(manager.isOperationActive(operations[2].id))
    }
    
    // MARK: - Priority Tests
    
    @Test("Test operation priorities", tags: ["operation", "priority"])
    func testPriorities() throws {
        // Given: Operation manager
        let context = TestContext()
        let manager = context.createOperationManager()
        
        // Test different priority operations
        let priorities = MockData.Operation.priorities
        for priority in priorities {
            let operation = BackupOperation(
                type: .backup,
                source: "/test",
                destination: "/backup",
                priority: priority
            )
            
            try manager.addOperation(operation)
            
            // Verify priority handling
            let queuePosition = manager.getQueuePosition(operation.id)
            switch priority {
            case .high:
                #expect(queuePosition == 0)
            case .normal:
                #expect(queuePosition > 0)
            case .low:
                #expect(queuePosition == manager.operations.count - 1)
            }
        }
    }
    
    // MARK: - Pause/Resume Tests
    
    @Test("Test operation pause and resume", tags: ["operation", "control"])
    func testPauseResume() throws {
        // Given: Operation manager with active operation
        let context = TestContext()
        let manager = context.createOperationManager()
        
        let operation = MockData.Operation.validOperations[0]
        try manager.addOperation(operation)
        try manager.startOperation(operation.id)
        
        // Test pause
        try manager.pauseOperation(operation.id)
        #expect(manager.getOperation(operation.id)?.status == .paused)
        #expect(context.resticService.pauseCalled)
        
        // Test resume
        try manager.resumeOperation(operation.id)
        #expect(manager.getOperation(operation.id)?.status == .running)
        #expect(context.resticService.resumeCalled)
        
        // Test global pause
        manager.pauseAllOperations()
        #expect(manager.isPaused)
        #expect(manager.getOperation(operation.id)?.status == .paused)
        
        // Test global resume
        manager.resumeAllOperations()
        #expect(!manager.isPaused)
        #expect(manager.getOperation(operation.id)?.status == .running)
    }
    
    // MARK: - Cancellation Tests
    
    @Test("Test operation cancellation", tags: ["operation", "cancel"])
    func testCancellation() throws {
        // Given: Operation manager with active operation
        let context = TestContext()
        let manager = context.createOperationManager()
        
        let operation = MockData.Operation.validOperations[0]
        try manager.addOperation(operation)
        try manager.startOperation(operation.id)
        
        // Test cancellation
        try manager.cancelOperation(operation.id)
        #expect(manager.getOperation(operation.id)?.status == .cancelled)
        #expect(!manager.isOperationActive(operation.id))
        #expect(context.resticService.cancelCalled)
        
        // Test cancel all
        let operations = Array(MockData.Operation.validOperations.prefix(3))
        for op in operations {
            try manager.addOperation(op)
            try manager.startOperation(op.id)
        }
        
        manager.cancelAllOperations()
        for op in operations {
            #expect(manager.getOperation(op.id)?.status == .cancelled)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test operation error handling", tags: ["operation", "error"])
    func testErrorHandling() throws {
        // Given: Operation manager
        let context = TestContext()
        let manager = context.createOperationManager()
        
        let operation = MockData.Operation.validOperations[0]
        try manager.addOperation(operation)
        
        // Test operation failure
        context.resticService.shouldFail = true
        try manager.startOperation(operation.id)
        
        #expect(manager.getOperation(operation.id)?.status == .failed)
        #expect(manager.getOperation(operation.id)?.error != nil)
        #expect(!manager.isOperationActive(operation.id))
        
        // Test retry
        context.resticService.shouldFail = false
        try manager.retryOperation(operation.id)
        
        #expect(manager.getOperation(operation.id)?.status == .running)
        #expect(manager.getOperation(operation.id)?.error == nil)
        #expect(manager.isOperationActive(operation.id))
    }
    
    // MARK: - Persistence Tests
    
    @Test("Test operation persistence", tags: ["operation", "persistence"])
    func testPersistence() throws {
        // Given: Operation manager with operations
        let context = TestContext()
        let manager = context.createOperationManager()
        
        let operations = MockData.Operation.validOperations
        for operation in operations {
            try manager.addOperation(operation)
        }
        
        // When: Saving state
        try manager.save()
        
        // Then: State is persisted
        let loadedManager = context.createOperationManager()
        try loadedManager.load()
        
        #expect(loadedManager.operations == manager.operations)
        #expect(loadedManager.maxConcurrentOperations == manager.maxConcurrentOperations)
        #expect(loadedManager.isPaused == manager.isPaused)
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle operation edge cases", tags: ["operation", "edge"])
    func testEdgeCases() throws {
        // Given: Operation manager
        let context = TestContext()
        let manager = context.createOperationManager()
        
        // Test invalid operation
        do {
            try manager.addOperation(BackupOperation(
                type: .backup,
                source: "",
                destination: ""
            ))
            throw TestFailure("Expected error for invalid operation")
        } catch {
            // Expected error
        }
        
        // Test non-existent operation
        do {
            try manager.startOperation(UUID())
            throw TestFailure("Expected error for non-existent operation")
        } catch {
            // Expected error
        }
        
        // Test invalid state transitions
        let operation = MockData.Operation.validOperations[0]
        try manager.addOperation(operation)
        
        do {
            try manager.pauseOperation(operation.id)
            throw TestFailure("Expected error for pausing non-running operation")
        } catch {
            // Expected error
        }
        
        // Test concurrent operation limit
        manager.maxConcurrentOperations = 0
        do {
            try manager.startOperation(operation.id)
            throw TestFailure("Expected error for zero concurrent operations")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test operation performance", tags: ["operation", "performance"])
    func testPerformance() throws {
        // Given: Operation manager
        let context = TestContext()
        let manager = context.createOperationManager()
        
        // Test rapid operation creation
        let startTime = context.dateProvider.now()
        for i in 0..<1000 {
            try manager.addOperation(BackupOperation(
                type: .backup,
                source: "/test/\(i)",
                destination: "/backup/\(i)"
            ))
        }
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test operation lookup performance
        let lookupStartTime = context.dateProvider.now()
        for _ in 0..<1000 {
            _ = manager.operations.first
        }
        let lookupEndTime = context.dateProvider.now()
        
        let lookupInterval = lookupEndTime.timeIntervalSince(lookupStartTime)
        #expect(lookupInterval < 0.1) // Lookup should be fast
    }
    
    // MARK: - Background Operation Tests
    
    @Test("Test background operation handling", tags: ["background", "operation"])
    func testBackgroundOperations() async throws {
        // Given: Operation manager with background configuration
        let context = TestContext()
        let manager = context.createOperationManager()
        
        let operation = MockData.Operation.backgroundOperation
        
        // When: Starting background operation
        try await manager.startBackgroundOperation(operation)
        
        // Then: Operation runs in background
        #expect(manager.activeOperations.count == 1)
        #expect(manager.activeOperations.first?.isBackgroundOperation == true)
        
        // Verify background task handling
        #expect(context.notificationCenter.backgroundTaskIdentifier != .invalid)
        #expect(context.notificationCenter.hasBackgroundTask)
        
        // When: Operation completes
        try await manager.completeOperation(operation.id)
        
        // Then: Background task is ended properly
        #expect(context.notificationCenter.backgroundTaskIdentifier == .invalid)
        #expect(!context.notificationCenter.hasBackgroundTask)
        #expect(manager.activeOperations.isEmpty)
    }
    
    // MARK: - System Sleep/Wake Tests
    
    @Test("Test system sleep/wake cycle handling", tags: ["system", "sleep"])
    func testSystemSleepWakeHandling() async throws {
        // Given: Operation manager
        let context = TestContext()
        let manager = context.createOperationManager()
        
        let operation = MockData.Operation.validOperations.first!
        try await manager.addOperation(operation)
        
        // When: System goes to sleep
        NotificationCenter.default.post(name: NSWorkspace.willSleepNotification, object: nil)
        
        // Then: Operations are paused
        #expect(manager.isPaused)
        #expect(manager.activeOperations.allSatisfy { $0.status == .paused })
        
        // When: System wakes up
        NotificationCenter.default.post(name: NSWorkspace.didWakeNotification, object: nil)
        
        // Then: Operations resume
        #expect(!manager.isPaused)
        #expect(manager.activeOperations.allSatisfy { $0.status == .running })
        
        // Verify operation state is preserved
        let resumedOperation = manager.getOperation(operation.id)
        #expect(resumedOperation?.progress == operation.progress)
    }
    
    // MARK: - FSEvents Tests
    
    @Test("Test FSEvents integration", tags: ["fsevents", "monitoring"])
    func testFSEventsIntegration() async throws {
        // Given: Operation manager with FSEvents monitoring
        let context = TestContext()
        let manager = context.createOperationManager()
        
        let sourcePath = "/test/backup/source"
        let operation = MockData.Operation.createWithSource(sourcePath)
        
        // When: Starting FSEvents monitoring
        try await manager.startMonitoring(sourcePath)
        
        // Then: FSEvents stream is created
        #expect(context.fileManager.fsEventStreamCreated)
        #expect(context.fileManager.monitoredPaths.contains(sourcePath))
        
        // When: File changes occur
        context.fileManager.simulateFileChanges(at: sourcePath)
        
        // Then: Changes are detected and handled
        #expect(context.notificationCenter.postCalled)
        #expect(context.progressTracker.updateProgressCalled)
        
        // When: File changes stabilise
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then: Backup is triggered
        #expect(manager.activeOperations.count == 1)
        let backupOperation = manager.activeOperations.first
        #expect(backupOperation?.source == sourcePath)
        
        // When: Stopping monitoring
        try await manager.stopMonitoring(sourcePath)
        
        // Then: FSEvents stream is stopped
        #expect(!context.fileManager.fsEventStreamCreated)
        #expect(!context.fileManager.monitoredPaths.contains(sourcePath))
    }
    
    // MARK: - Enhanced Error Handling Tests
    
    @Test("Test enhanced error handling with edge cases", tags: ["error", "edge"])
    func testEnhancedErrorHandling() async throws {
        // Given: Operation manager
        let context = TestContext()
        let manager = context.createOperationManager()
        
        // Test case 1: Network disconnection during backup
        let networkOperation = MockData.Operation.networkOperation
        try await manager.addOperation(networkOperation)
        context.resticService.simulateNetworkFailure = true
        
        do {
            try await manager.executeOperation(networkOperation.id)
            XCTFail("Should have thrown network error")
        } catch {
            #expect(error is BackupError)
            #expect((error as? BackupError)?.isNetworkError == true)
            #expect(manager.getOperation(networkOperation.id)?.status == .failed)
        }
        
        // Test case 2: Insufficient disk space
        let largeOperation = MockData.Operation.largeOperation
        try await manager.addOperation(largeOperation)
        context.fileManager.simulateDiskSpaceError = true
        
        do {
            try await manager.executeOperation(largeOperation.id)
            XCTFail("Should have thrown disk space error")
        } catch {
            #expect(error is BackupError)
            #expect((error as? BackupError)?.isDiskSpaceError == true)
            #expect(manager.getOperation(largeOperation.id)?.status == .failed)
        }
        
        // Test case 3: Permission changes during backup
        let permissionOperation = MockData.Operation.permissionOperation
        try await manager.addOperation(permissionOperation)
        context.fileManager.simulatePermissionChange = true
        
        do {
            try await manager.executeOperation(permissionOperation.id)
            XCTFail("Should have thrown permission error")
        } catch {
            #expect(error is BackupError)
            #expect((error as? BackupError)?.isPermissionError == true)
            #expect(manager.getOperation(permissionOperation.id)?.status == .failed)
        }
        
        // Verify error recovery
        try await manager.retryOperation(permissionOperation.id)
        #expect(manager.getOperation(permissionOperation.id)?.status == .running)
    }
}

// MARK: - Mock Progress Tracker

/// Mock implementation of ProgressTracker for testing
final class MockProgressTracker: ProgressTrackerProtocol {
    private var progressHandler: ((Double) -> Void)?
    private var completionHandler: (() -> Void)?
    private(set) var startCalled: Bool = false
    
    func start(progressHandler: @escaping (Double) -> Void, completionHandler: @escaping () -> Void) {
        startCalled = true
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
    }
    
    func stop() {
        progressHandler = nil
        completionHandler = nil
        startCalled = false
    }
    
    func simulateProgress(_ progress: Double) {
        progressHandler?(progress)
    }
    
    func simulateCompletion() {
        completionHandler?()
    }
    
    func reset() {
        stop()
    }
}
