//
//  BackupQueueTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

/// Error thrown when a test assertion fails
struct TestFailure: Error, CustomStringConvertible {
    /// Description of why the test failed
    let description: String
    
    /// Create a new test failure
    /// - Parameter description: Description of why the test failed
    init(_ description: String) {
        self.description = description
    }
}

/// Tests for BackupQueue functionality
struct BackupQueueTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let dateProvider: TestMocksModule.TestMocks.MockDateProvider
        let notificationCenter: TestMocksModule.TestMocks.MockNotificationCenter
        let progressTracker: TestMocksModule.TestMocks.MockProgressTracker
        
        init() {
            self.dateProvider = TestMocksModule.TestMocks.MockDateProvider()
            self.notificationCenter = TestMocksModule.TestMocks.MockNotificationCenter()
            self.progressTracker = TestMocksModule.TestMocks.MockProgressTracker()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            dateProvider.reset()
            notificationCenter.reset()
            progressTracker.reset()
        }
        
        /// Create a backup queue for testing
        func createQueue() -> BackupQueue {
            BackupQueue(
                dateProvider: dateProvider,
                notificationCenter: notificationCenter,
                progressTracker: progressTracker
            )
        }
    }
    
    // MARK: - Test Data
    
    /// Mock data for testing
    enum MockData {
        /// Mock backup jobs
        enum BackupJob {
            /// Valid backup jobs for testing
            static let validJobs: [rBUM.BackupJob] = [
                rBUM.BackupJob(id: UUID(), priority: .high),
                rBUM.BackupJob(id: UUID(), priority: .medium),
                rBUM.BackupJob(id: UUID(), priority: .low)
            ]
            
            /// Jobs with different priorities for testing
            static let priorityJobs: [rBUM.BackupJob] = [
                rBUM.BackupJob(id: UUID(), priority: .high),
                rBUM.BackupJob(id: UUID(), priority: .high),
                rBUM.BackupJob(id: UUID(), priority: .medium),
                rBUM.BackupJob(id: UUID(), priority: .low)
            ]
            
            /// Jobs that can run concurrently
            static let concurrentJobs: [rBUM.BackupJob] = [
                rBUM.BackupJob(id: UUID(), priority: .medium),
                rBUM.BackupJob(id: UUID(), priority: .medium),
                rBUM.BackupJob(id: UUID(), priority: .medium)
            ]
            
            /// Jobs for testing progress tracking
            static let progressJobs: [rBUM.BackupJob] = [
                rBUM.BackupJob(id: UUID(), priority: .high),
                rBUM.BackupJob(id: UUID(), priority: .medium)
            ]
            
            /// Jobs that will fail
            static let errorJobs: [rBUM.BackupJob] = [
                rBUM.BackupJob(id: UUID(), priority: .high),
                rBUM.BackupJob(id: UUID(), priority: .low)
            ]
        }
    }
    
    // MARK: - Test Errors
    
    /// Errors used for testing
    enum TestError: Error {
        case testFailure(String)
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup queue", ["init", "queue"] as! TestTrait)
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating queue
        let queue = context.createQueue()
        
        // Then: Queue is empty and properly configured
        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(!queue.isProcessingJobs)
    }
    
    // MARK: - Queue Management Tests
    
    @Test("Test basic queue operations", ["queue", "basic"] as! TestTrait)
    func testBasicOperations() throws {
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
        for (index, expectedJob) in jobs.enumerated() {
            guard let job = queue.peek() else {
                throw TestFailure("Expected job at index \(index)")
            }
            #expect(job.id == expectedJob.id)
        }
        
        // Test dequeuing jobs
        for job in jobs {
            try queue.dequeue(job)
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
        
        #expect(queue.isEmpty)
    }
    
    // MARK: - Priority Tests
    
    @Test("Test job priority ordering", ["priority", "queue"] as! TestTrait)
    func testJobPriorityOrdering() throws {
        // Given: Queue with jobs of different priorities
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.priorityJobs
        
        // Test priority ordering
        for job in jobs {
            try queue.enqueue(job)
        }
        
        // Then: Queue should be ordered by priority
        #expect(!queue.isEmpty)
        #expect(queue.count == jobs.count)
        #expect(!queue.isProcessingJobs)
        
        // And: Next job should be highest priority
        guard let nextJob = queue.peek() else {
            throw TestFailure("Expected next job")
        }
        #expect(nextJob.priority == .high)
    }
    
    // MARK: - Concurrent Processing Tests
    
    @Test("Test concurrent job processing", ["concurrent", "queue"] as! TestTrait)
    func testConcurrentProcessing() throws {
        // Given: Queue with multiple jobs
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.concurrentJobs
        
        // Test concurrent job handling
        for job in jobs {
            try queue.enqueue(job)
        }
        
        // When: Start processing
        queue.startProcessing()
        
        // Then: Should be processing jobs
        #expect(queue.isProcessingJobs)
        #expect(queue.processingJobs.count == min(jobs.count, queue.maxConcurrentJobs))
    }
    
    // MARK: - Progress Tests
    
    @Test("Test job progress tracking", ["progress", "queue"] as! TestTrait)
    func testProgressTracking() throws {
        // Given: Queue with jobs
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.progressJobs
        
        // Add jobs and start processing
        for job in jobs {
            try queue.enqueue(job)
        }
        
        // When: Start processing and update progress
        queue.startProcessing()
        
        // Then: Progress should be tracked
        #expect(queue.overallProgress == 0.0)
        
        // When: Update progress
        queue.updateProgress(forJob: jobs[0].id, progress: 0.5, message: "Halfway done")
        
        // Then: Progress should be updated
        #expect(queue.overallProgress == 0.25)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test error handling", ["error", "queue"] as! TestTrait)
    func testErrorHandling() throws {
        // Given: Queue with jobs
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.errorJobs
        
        // Test error handling for each job
        for job in jobs {
            try queue.enqueue(job)
        }
        
        // When: Handle error for job
        queue.handleError(TestError.testFailure("Test error"), forJob: jobs[0].id)
        
        // Then: Job should be removed from processing
        #expect(!queue.processingJobs.contains(jobs[0].id))
    }
    
    // MARK: - Persistence Tests
    
    @Test("Test queue persistence", ["persistence", "queue"] as! TestTrait)
    func testQueuePersistence() throws {
        // Given: Queue with jobs
        let context = TestContext()
        let queue = context.createQueue()
        
        let jobs = MockData.BackupJob.validJobs
        for job in jobs {
            try queue.enqueue(job)
        }
        
        // When: Save and load queue
        try queue.save()
        try queue.load()
        
        // Then: Queue should have same jobs
        #expect(queue.count == jobs.count)
        #expect(queue.peek()?.id == jobs[0].id)
    }
    
    // MARK: - Edge Cases
    
    @Test("Test edge cases", ["edge", "queue"] as! TestTrait)
    func testEdgeCases() throws {
        // Given: Empty queue
        let context = TestContext()
        let queue = context.createQueue()
        
        // Test empty queue operations
        #expect(queue.isEmpty)
        #expect(queue.peek() == nil)
        #expect(queue.count == 0)
        
        // Test duplicate job
        let job = MockData.BackupJob.validJobs[0]
        try queue.enqueue(job)
        do {
            try queue.enqueue(job)
            throw TestFailure("Expected duplicate job error")
        } catch BackupQueueError.duplicateJob {
            // Expected error
        }
        
        // Test job not found
        do {
            try queue.dequeue(BackupJob(id: UUID(), priority: .medium))
            throw TestFailure("Expected job not found error")
        } catch BackupQueueError.jobNotFound {
            // Expected error
        }
        
        // Test finding non-existent job
        #expect(queue.findJob(withId: UUID()) == nil)
    }
    
    // MARK: - Performance Tests
    
    @Test("Test queue performance", ["queue", "performance"] as! TestTrait)
    func testPerformance() throws {
        // Given: Queue
        let context = TestContext()
        let queue = context.createQueue()
        
        // Test enqueue performance
        let startTime = context.dateProvider.currentDate()
        for _ in 0..<1000 {
            try queue.enqueue(BackupJob(id: UUID(), priority: .medium))
        }
        let endTime = context.dateProvider.currentDate()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test job lookup performance
        let lookupStartTime = context.dateProvider.currentDate()
        _ = queue.findJob(withId: UUID())
        let lookupEndTime = context.dateProvider.currentDate()
        
        let lookupInterval = lookupEndTime.timeIntervalSince(lookupStartTime)
        #expect(lookupInterval < 0.1) // Job lookups should be fast
    }
}
