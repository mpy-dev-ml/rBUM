import Testing
@testable import rBUM

/// Tests for BackupProgress functionality
struct BackupProgressTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let dateProvider: MockDateProvider
        let notificationCenter: MockNotificationCenter
        let progressTracker: MockProgressTracker
        
        init() {
            self.dateProvider = MockDateProvider()
            self.notificationCenter = MockNotificationCenter()
            self.progressTracker = MockProgressTracker()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            dateProvider.reset()
            notificationCenter.reset()
            progressTracker.reset()
        }
        
        /// Create test progress tracker
        func createProgressTracker() -> BackupProgressTracker {
            BackupProgressTracker(
                dateProvider: dateProvider,
                notificationCenter: notificationCenter,
                progressTracker: progressTracker
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup progress tracker", tags: ["init", "progress"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating progress tracker
        let tracker = context.createProgressTracker()
        
        // Then: Tracker is properly initialized
        #expect(tracker.totalProgress == 0.0)
        #expect(tracker.activeOperations.isEmpty)
        #expect(!tracker.isActive)
    }
    
    // MARK: - Progress Tracking Tests
    
    @Test("Test progress tracking", tags: ["progress", "core"])
    func testProgressTracking() throws {
        // Given: Progress tracker
        let context = TestContext()
        let tracker = context.createProgressTracker()
        
        let operations = MockData.Progress.validOperations
        
        // Test starting operations
        for operation in operations {
            try tracker.startOperation(operation)
            #expect(tracker.isActive)
            #expect(tracker.activeOperations.contains(operation))
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
        
        // Test updating progress
        for operation in operations {
            try tracker.updateProgress(0.5, for: operation.id)
            #expect(context.progressTracker.updateProgressCalled)
            #expect(context.progressTracker.lastProgress == 0.5)
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
        
        // Test completing operations
        for operation in operations {
            try tracker.completeOperation(operation.id)
            #expect(!tracker.activeOperations.contains(operation))
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Progress Calculation Tests
    
    @Test("Test progress calculations", tags: ["progress", "calculation"])
    func testProgressCalculations() throws {
        // Given: Progress tracker with operations
        let context = TestContext()
        let tracker = context.createProgressTracker()
        
        let operations = MockData.Progress.calculationOperations
        
        // Add operations with different weights
        for operation in operations {
            try tracker.startOperation(operation)
        }
        
        // Test weighted progress calculation
        var totalWeight: Double = 0
        var weightedProgress: Double = 0
        
        for operation in operations {
            let progress = Double.random(in: 0...1)
            try tracker.updateProgress(progress, for: operation.id)
            
            totalWeight += operation.weight
            weightedProgress += progress * operation.weight
        }
        
        let expectedProgress = weightedProgress / totalWeight
        #expect(abs(tracker.totalProgress - expectedProgress) < 0.001)
    }
    
    // MARK: - Time Estimation Tests
    
    @Test("Test time estimations", tags: ["progress", "time"])
    func testTimeEstimations() throws {
        // Given: Progress tracker
        let context = TestContext()
        let tracker = context.createProgressTracker()
        
        let operation = MockData.Progress.timeEstimationOperation
        try tracker.startOperation(operation)
        
        // Test time estimation updates
        let startTime = context.dateProvider.now()
        try tracker.updateProgress(0.5, for: operation.id)
        
        // Simulate time passing
        context.dateProvider.advanceTime(by: 60) // 1 minute
        
        // Calculate estimated time remaining
        let remaining = tracker.estimatedTimeRemaining
        #expect(remaining != nil)
        if let remaining = remaining {
            let expectedRemaining = 60.0 // Another minute based on current progress
            #expect(abs(remaining - expectedRemaining) < 5.0) // Allow 5 second margin
        }
    }
    
    // MARK: - Status Tests
    
    @Test("Test progress status handling", tags: ["progress", "status"])
    func testStatusHandling() throws {
        // Given: Progress tracker
        let context = TestContext()
        let tracker = context.createProgressTracker()
        
        let operations = MockData.Progress.statusOperations
        
        // Test different operation statuses
        for operation in operations {
            try tracker.startOperation(operation)
            
            switch operation.status {
            case .preparing:
                #expect(tracker.status == .preparing)
            case .processing:
                #expect(tracker.status == .processing)
            case .finalizing:
                #expect(tracker.status == .finalizing)
            case .completed:
                #expect(tracker.status == .completed)
            case .failed:
                #expect(tracker.status == .failed)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test progress error handling", tags: ["progress", "error"])
    func testErrorHandling() throws {
        // Given: Progress tracker
        let context = TestContext()
        let tracker = context.createProgressTracker()
        
        let operations = MockData.Progress.errorOperations
        
        // Test error handling for each operation
        for operation in operations {
            try tracker.startOperation(operation)
            
            // Simulate error
            let error = BackupError.operationFailed(reason: "Test error")
            try tracker.handleError(error, for: operation.id)
            
            #expect(tracker.status == .failed)
            #expect(context.notificationCenter.postNotificationCalled)
            let notification = context.notificationCenter.lastPostedNotification
            #expect(notification?.name == .backupProgressFailed)
            
            context.reset()
        }
    }
    
    // MARK: - Persistence Tests
    
    @Test("Test progress persistence", tags: ["progress", "persistence"])
    func testPersistence() throws {
        // Given: Progress tracker with operations
        let context = TestContext()
        let tracker = context.createProgressTracker()
        
        let operations = MockData.Progress.validOperations
        for operation in operations {
            try tracker.startOperation(operation)
            try tracker.updateProgress(0.5, for: operation.id)
        }
        
        // When: Saving state
        try tracker.save()
        
        // Then: State is persisted
        let loadedTracker = context.createProgressTracker()
        try loadedTracker.load()
        
        #expect(loadedTracker.activeOperations.count == operations.count)
        for operation in operations {
            #expect(loadedTracker.getProgress(for: operation.id) == 0.5)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle progress edge cases", tags: ["progress", "edge"])
    func testEdgeCases() throws {
        // Given: Progress tracker
        let context = TestContext()
        let tracker = context.createProgressTracker()
        
        // Test invalid operation ID
        do {
            try tracker.updateProgress(0.5, for: UUID())
            throw TestFailure("Expected error for invalid operation ID")
        } catch {
            // Expected error
        }
        
        // Test invalid progress values
        let operation = MockData.Progress.validOperations[0]
        try tracker.startOperation(operation)
        
        do {
            try tracker.updateProgress(-0.1, for: operation.id)
            throw TestFailure("Expected error for negative progress")
        } catch {
            // Expected error
        }
        
        do {
            try tracker.updateProgress(1.1, for: operation.id)
            throw TestFailure("Expected error for progress > 1")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test progress performance", tags: ["progress", "performance"])
    func testPerformance() throws {
        // Given: Progress tracker
        let context = TestContext()
        let tracker = context.createProgressTracker()
        
        // Test rapid progress updates
        let startTime = context.dateProvider.now()
        let operation = MockData.Progress.validOperations[0]
        try tracker.startOperation(operation)
        
        for _ in 0..<1000 {
            let progress = Double.random(in: 0...1)
            try tracker.updateProgress(progress, for: operation.id)
        }
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test progress calculation performance
        let calcStartTime = context.dateProvider.now()
        for _ in 0..<1000 {
            _ = tracker.totalProgress
        }
        let calcEndTime = context.dateProvider.now()
        
        let calcInterval = calcEndTime.timeIntervalSince(calcStartTime)
        #expect(calcInterval < 0.1) // Progress calculations should be fast
    }
}

// MARK: - Mock Implementations

/// Mock implementation of DateProvider for testing
final class MockDateProvider: DateProvider {
    var currentDate: Date = Date()
    
    func now() -> Date {
        currentDate
    }
    
    func reset() {
        currentDate = Date()
    }
    
    func advanceTime(by interval: TimeInterval) {
        currentDate = currentDate.addingTimeInterval(interval)
    }
}

/// Mock implementation of NotificationCenter for testing
final class MockNotificationCenter: NotificationCenter {
    var postCalled = false
    var lastPostedNotification: Notification?
    
    override func post(_ notification: Notification) {
        postCalled = true
        lastPostedNotification = notification
    }
    
    func reset() {
        postCalled = false
        lastPostedNotification = nil
    }
}

/// Mock implementation of ProgressTracker for testing
final class MockProgressTracker: ProgressTracker {
    var updateProgressCalled = false
    var lastProgress: Double?
    
    func updateProgress(_ progress: Double, for operationId: UUID) {
        updateProgressCalled = true
        lastProgress = progress
    }
    
    func reset() {
        updateProgressCalled = false
        lastProgress = nil
    }
}
