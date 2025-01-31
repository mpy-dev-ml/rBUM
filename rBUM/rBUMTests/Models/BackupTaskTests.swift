import Testing
@testable import rBUM

/// Tests for BackupTask functionality
struct BackupTaskTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let resticService: MockResticService
        let notificationCenter: MockNotificationCenter
        let dateProvider: MockDateProvider
        let progressTracker: MockProgressTracker
        let fileManager: MockFileManager
        
        init() {
            self.resticService = MockResticService()
            self.notificationCenter = MockNotificationCenter()
            self.dateProvider = MockDateProvider()
            self.progressTracker = MockProgressTracker()
            self.fileManager = MockFileManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            resticService.reset()
            notificationCenter.reset()
            dateProvider.reset()
            progressTracker.reset()
            fileManager.reset()
        }
        
        /// Create test task manager
        func createTaskManager() -> BackupTaskManager {
            BackupTaskManager(
                resticService: resticService,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider,
                progressTracker: progressTracker,
                fileManager: fileManager
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize task manager", tags: ["init", "task"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating task manager
        let manager = context.createTaskManager()
        
        // Then: Manager is properly configured
        #expect(manager.isInitialized)
        #expect(manager.taskCount == 0)
    }
    
    // MARK: - Task Creation Tests
    
    @Test("Test task creation", tags: ["task", "create"])
    func testTaskCreation() throws {
        // Given: Task manager
        let context = TestContext()
        let manager = context.createTaskManager()
        
        let testData = MockData.Task.creationData
        
        // Test task creation
        for data in testData {
            // Create task
            let task = try manager.createTask(data)
            #expect(task.id != nil)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify task
            let verified = try manager.verifyTask(task)
            #expect(verified)
            
            context.reset()
        }
    }
    
    // MARK: - Task Execution Tests
    
    @Test("Test task execution", tags: ["task", "execute"])
    func testTaskExecution() throws {
        // Given: Task manager
        let context = TestContext()
        let manager = context.createTaskManager()
        
        let testCases = MockData.Task.executionData
        
        // Test task execution
        for testCase in testCases {
            // Create and execute task
            let task = try manager.createTask(testCase.task)
            try manager.executeTask(task)
            
            // Verify execution
            #expect(context.resticService.executeTaskCalled)
            #expect(context.progressTracker.trackProgressCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Check task status
            let status = try manager.getTaskStatus(task)
            #expect(status == testCase.expectedStatus)
            
            context.reset()
        }
    }
    
    // MARK: - Task Progress Tests
    
    @Test("Test task progress tracking", tags: ["task", "progress"])
    func testTaskProgress() throws {
        // Given: Task manager
        let context = TestContext()
        let manager = context.createTaskManager()
        
        let testCases = MockData.Task.progressData
        
        // Test progress tracking
        for testCase in testCases {
            // Create and start task
            let task = try manager.createTask(testCase.task)
            try manager.startTask(task)
            
            // Update progress
            try manager.updateTaskProgress(task, progress: testCase.progress)
            #expect(context.progressTracker.updateProgressCalled)
            
            // Verify progress
            let progress = try manager.getTaskProgress(task)
            #expect(progress == testCase.expectedProgress)
            
            context.reset()
        }
    }
    
    // MARK: - Task Cancellation Tests
    
    @Test("Test task cancellation", tags: ["task", "cancel"])
    func testTaskCancellation() throws {
        // Given: Task manager
        let context = TestContext()
        let manager = context.createTaskManager()
        
        let testCases = MockData.Task.cancellationData
        
        // Test task cancellation
        for testCase in testCases {
            // Create and start task
            let task = try manager.createTask(testCase.task)
            try manager.startTask(task)
            
            // Cancel task
            try manager.cancelTask(task)
            #expect(context.resticService.cancelTaskCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify cancellation
            let status = try manager.getTaskStatus(task)
            #expect(status == .cancelled)
            
            context.reset()
        }
    }
    
    // MARK: - Task Dependencies Tests
    
    @Test("Test task dependencies", tags: ["task", "dependencies"])
    func testTaskDependencies() throws {
        // Given: Task manager
        let context = TestContext()
        let manager = context.createTaskManager()
        
        let testCases = MockData.Task.dependencyData
        
        // Test task dependencies
        for testCase in testCases {
            // Create tasks
            let tasks = try testCase.tasks.map { try manager.createTask($0) }
            
            // Add dependencies
            for (task, dependencies) in zip(tasks, testCase.dependencies) {
                try manager.addTaskDependencies(task, dependencies: dependencies)
            }
            
            // Execute tasks
            for task in tasks {
                try manager.executeTask(task)
            }
            
            // Verify execution order
            let executionOrder = context.resticService.executedTasks
            #expect(executionOrder == testCase.expectedOrder)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test task error handling", tags: ["task", "error"])
    func testErrorHandling() throws {
        // Given: Task manager
        let context = TestContext()
        let manager = context.createTaskManager()
        
        let errorCases = MockData.Task.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                try manager.handleTaskOperation(errorCase)
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Expected error
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .backupTaskError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle task edge cases", tags: ["task", "edge"])
    func testEdgeCases() throws {
        // Given: Task manager
        let context = TestContext()
        let manager = context.createTaskManager()
        
        // Test invalid task
        do {
            try manager.verifyTask(BackupTask(id: "invalid"))
            throw TestFailure("Expected error for invalid task")
        } catch {
            // Expected error
        }
        
        // Test duplicate task
        do {
            let task = try manager.createTask(name: "test")
            try manager.addTask(task)
            try manager.addTask(task)
            throw TestFailure("Expected error for duplicate task")
        } catch {
            // Expected error
        }
        
        // Test circular dependencies
        do {
            let task1 = try manager.createTask(name: "task1")
            let task2 = try manager.createTask(name: "task2")
            try manager.addTaskDependencies(task1, dependencies: [task2])
            try manager.addTaskDependencies(task2, dependencies: [task1])
            throw TestFailure("Expected error for circular dependencies")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test task performance", tags: ["task", "performance"])
    func testPerformance() throws {
        // Given: Task manager
        let context = TestContext()
        let manager = context.createTaskManager()
        
        // Test execution performance
        let startTime = context.dateProvider.now()
        let testTask = try manager.createTask(MockData.Task.executionData[0].task)
        
        for _ in 0..<100 {
            try manager.executeTask(testTask)
        }
        
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test dependency resolution performance
        let dependencyStartTime = context.dateProvider.now()
        let tasks = try (0..<100).map { try manager.createTask(name: "task\($0)") }
        
        for i in 1..<tasks.count {
            try manager.addTaskDependencies(tasks[i], dependencies: [tasks[i-1]])
        }
        
        let dependencyEndTime = context.dateProvider.now()
        
        let dependencyInterval = dependencyEndTime.timeIntervalSince(dependencyStartTime)
        #expect(dependencyInterval < 0.5) // Dependency resolution should be fast
    }
}
