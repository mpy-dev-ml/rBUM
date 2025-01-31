//
//  BackupQueueTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupQueue functionality
struct BackupQueueTests {
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
        
        /// Create test queue
        func createQueue() -> BackupQueue {
            BackupQueue(
                dateProvider: dateProvider,
                notificationCenter: notificationCenter,
                progressTracker: progressTracker
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup queue", tags: ["init", "queue"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating queue
        let queue = context.createQueue()
        
        // Then: Queue is empty and properly configured
        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(!queue.isProcessing)
    }
    
    // MARK: - Queue Management Tests
    
    @Test("Test queue management", tags: ["queue", "core"])
    func testQueueManagement() throws {
        // Given: Queue
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.validJobs
        
        // Test enqueueing jobs
        for job in jobs {
            try queue.enqueue(job)
            #expect(!queue.isEmpty)
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
        
        // Test job order
        #expect(queue.count == jobs.count)
        for (index, job) in jobs.enumerated() {
            #expect(queue.peek(at: index)?.id == job.id)
        }
        
        // Test dequeuing jobs
        for job in jobs {
            let dequeued = try queue.dequeue()
            #expect(dequeued.id == job.id)
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
        
        #expect(queue.isEmpty)
    }
    
    // MARK: - Priority Tests
    
    @Test("Test queue priority handling", tags: ["queue", "priority"])
    func testPriorityHandling() throws {
        // Given: Queue
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.priorityJobs
        
        // Test priority ordering
        for job in jobs {
            try queue.enqueue(job)
        }
        
        // Verify jobs are ordered by priority
        var lastPriority = BackupJobPriority.high
        while !queue.isEmpty {
            let job = try queue.dequeue()
            #expect(job.priority.rawValue <= lastPriority.rawValue)
            lastPriority = job.priority
        }
    }
    
    // MARK: - Concurrency Tests
    
    @Test("Test queue concurrency", tags: ["queue", "concurrency"])
    func testConcurrency() throws {
        // Given: Queue
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.concurrentJobs
        
        // Test concurrent job handling
        for job in jobs {
            try queue.enqueue(job)
        }
        
        // Test concurrent processing
        try queue.startProcessing()
        #expect(queue.isProcessing)
        
        // Verify concurrent job limits
        let processingCount = queue.processingJobs.count
        #expect(processingCount <= queue.maxConcurrentJobs)
        
        // Test job completion
        try queue.completeJob(jobs[0].id)
        #expect(queue.processingJobs.count < processingCount)
    }
    
    // MARK: - Progress Tracking Tests
    
    @Test("Test queue progress tracking", tags: ["queue", "progress"])
    func testProgressTracking() throws {
        // Given: Queue with jobs
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.progressJobs
        
        // Add jobs and start processing
        for job in jobs {
            try queue.enqueue(job)
        }
        
        try queue.startProcessing()
        
        // Test progress updates
        for job in jobs {
            try queue.updateProgress(0.5, for: job.id)
            #expect(context.progressTracker.updateProgressCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
        
        // Test overall progress
        let progress = queue.overallProgress
        #expect(progress >= 0.0 && progress <= 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test queue error handling", tags: ["queue", "error"])
    func testErrorHandling() throws {
        // Given: Queue with jobs
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.errorJobs
        
        // Test error handling for each job
        for job in jobs {
            try queue.enqueue(job)
            
            // Simulate error
            let error = BackupError.jobFailed(reason: "Test error")
            try queue.handleError(error, for: job.id)
            
            #expect(context.notificationCenter.postNotificationCalled)
            let notification = context.notificationCenter.lastPostedNotification
            #expect(notification?.name == .backupJobFailed)
            
            context.reset()
        }
    }
    
    // MARK: - Persistence Tests
    
    @Test("Test queue persistence", tags: ["queue", "persistence"])
    func testPersistence() throws {
        // Given: Queue with jobs
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.validJobs
        for job in jobs {
            try queue.enqueue(job)
        }
        
        // When: Saving state
        try queue.save()
        
        // Then: State is persisted
        let loadedQueue = context.createQueue()
        try loadedQueue.load()
        
        #expect(loadedQueue.count == jobs.count)
        for (index, job) in jobs.enumerated() {
            #expect(loadedQueue.peek(at: index)?.id == job.id)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle queue edge cases", tags: ["queue", "edge"])
    func testEdgeCases() throws {
        // Given: Queue
        let context = TestContext()
        let queue = context.createQueue()
        
        // Test empty queue operations
        do {
            _ = try queue.dequeue()
            throw TestFailure("Expected error for empty queue")
        } catch {
            // Expected error
        }
        
        // Test invalid job ID
        do {
            try queue.updateProgress(0.5, for: UUID())
            throw TestFailure("Expected error for invalid job ID")
        } catch {
            // Expected error
        }
        
        // Test duplicate job
        let job = MockData.BackupJob.validJobs[0]
        try queue.enqueue(job)
        do {
            try queue.enqueue(job)
            throw TestFailure("Expected error for duplicate job")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test queue performance", tags: ["queue", "performance"])
    func testPerformance() throws {
        // Given: Queue
        let context = TestContext()
        let queue = context.createQueue()
        
        // Test rapid job enqueuing
        let startTime = context.dateProvider.now()
        for i in 0..<1000 {
            let job = BackupJob(
                id: UUID(),
                name: "Job \(i)",
                priority: .normal,
                created: context.dateProvider.now()
            )
            try queue.enqueue(job)
        }
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test job lookup performance
        let lookupStartTime = context.dateProvider.now()
        for _ in 0..<1000 {
            _ = queue.findJob(by: { _ in true })
        }
        let lookupEndTime = context.dateProvider.now()
        
        let lookupInterval = lookupEndTime.timeIntervalSince(lookupStartTime)
        #expect(lookupInterval < 0.1) // Job lookups should be fast
    }
}

// MARK: - Mock Progress Tracker

/// Mock implementation of ProgressTracker for testing
final class MockProgressTracker: ProgressTrackerProtocol {
    private(set) var updateProgressCalled = false
    private(set) var lastProgress: Double?
    
    func updateProgress(_ progress: Double, for id: UUID) {
        updateProgressCalled = true
        lastProgress = progress
    }
    
    func reset() {
        updateProgressCalled = false
        lastProgress = nil
    }
}
