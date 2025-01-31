//
//  BackupJobTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupJob functionality
struct BackupJobTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let notificationCenter: MockNotificationCenter
        let dateProvider: MockDateProvider
        let resticService: MockResticService
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.notificationCenter = MockNotificationCenter()
            self.dateProvider = MockDateProvider()
            self.resticService = MockResticService()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            notificationCenter.reset()
            dateProvider.reset()
            resticService.reset()
        }
        
        /// Create test job
        func createJob(
            id: String = MockData.Job.validId,
            name: String = MockData.Job.validName,
            status: BackupJobStatus = .pending,
            repository: Repository = MockData.Repository.validRepository,
            configuration: BackupConfiguration = MockData.Configuration.validConfiguration,
            progress: BackupProgress = MockData.Progress.validProgress,
            error: BackupError? = nil,
            startTime: Date? = nil,
            endTime: Date? = nil,
            retryCount: Int = 0,
            isEnabled: Bool = true
        ) -> BackupJob {
            BackupJob(
                id: id,
                name: name,
                status: status,
                repository: repository,
                configuration: configuration,
                progress: progress,
                error: error,
                startTime: startTime,
                endTime: endTime,
                retryCount: retryCount,
                isEnabled: isEnabled
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize with default values", tags: ["init", "job"])
    func testDefaultInitialization() throws {
        // Given: Default job parameters
        let context = TestContext()
        
        // When: Creating job
        let job = context.createJob()
        
        // Then: Job is configured correctly
        #expect(job.id == MockData.Job.validId)
        #expect(job.name == MockData.Job.validName)
        #expect(job.status == .pending)
        #expect(job.repository == MockData.Repository.validRepository)
        #expect(job.configuration == MockData.Configuration.validConfiguration)
        #expect(job.progress == MockData.Progress.validProgress)
        #expect(job.error == nil)
        #expect(job.startTime == nil)
        #expect(job.endTime == nil)
        #expect(job.retryCount == 0)
        #expect(job.isEnabled)
    }
    
    @Test("Initialize with custom values", tags: ["init", "job"])
    func testCustomInitialization() throws {
        // Given: Custom job parameters
        let context = TestContext()
        let customId = "custom-id"
        let customName = "Custom Job"
        let customRepository = MockData.Repository.customRepository
        let customConfiguration = MockData.Configuration.customConfiguration
        let customProgress = MockData.Progress.customProgress
        let customError = MockData.Error.validError
        let customStartTime = Date()
        let customEndTime = Date().addingTimeInterval(300)
        
        // When: Creating job
        let job = context.createJob(
            id: customId,
            name: customName,
            status: .running,
            repository: customRepository,
            configuration: customConfiguration,
            progress: customProgress,
            error: customError,
            startTime: customStartTime,
            endTime: customEndTime,
            retryCount: 2,
            isEnabled: false
        )
        
        // Then: Job is configured correctly
        #expect(job.id == customId)
        #expect(job.name == customName)
        #expect(job.status == .running)
        #expect(job.repository == customRepository)
        #expect(job.configuration == customConfiguration)
        #expect(job.progress == customProgress)
        #expect(job.error == customError)
        #expect(job.startTime == customStartTime)
        #expect(job.endTime == customEndTime)
        #expect(job.retryCount == 2)
        #expect(!job.isEnabled)
    }
    
    // MARK: - Status Tests
    
    @Test("Handle job status transitions", tags: ["status", "job"])
    func testStatusTransitions() throws {
        // Given: Job with different status transitions
        let context = TestContext()
        let testCases: [(BackupJobStatus, BackupJobStatus, Bool)] = [
            // Valid transitions
            (.pending, .running, true),
            (.running, .completed, true),
            (.running, .failed, true),
            (.failed, .pending, true),
            (.completed, .pending, true),
            
            // Invalid transitions
            (.completed, .running, false),
            (.failed, .completed, false),
            (.pending, .completed, false),
            (.running, .pending, false)
        ]
        
        // When/Then: Test status transitions
        for (fromStatus, toStatus, isValid) in testCases {
            var job = context.createJob(status: fromStatus)
            let canTransition = job.canTransitionTo(toStatus)
            #expect(canTransition == isValid)
            
            if isValid {
                job.status = toStatus
                #expect(job.status == toStatus)
            }
        }
    }
    
    // MARK: - Progress Tests
    
    @Test("Handle job progress updates", tags: ["progress", "job"])
    func testProgressUpdates() throws {
        // Given: Job with progress updates
        let context = TestContext()
        var job = context.createJob(status: .running)
        
        // Test progress updates
        let updates: [(Double, UInt64, TimeInterval)] = [
            (0.25, 256 * 1024, 60),
            (0.50, 512 * 1024, 120),
            (0.75, 768 * 1024, 180),
            (1.00, 1024 * 1024, 240)
        ]
        
        for (percentage, bytes, elapsed) in updates {
            // When: Updating progress
            job.progress.update(
                percentage: percentage,
                bytesProcessed: bytes,
                elapsedTime: elapsed
            )
            
            // Then: Progress is updated correctly
            #expect(job.progress.percentage == percentage)
            #expect(job.progress.bytesProcessed == bytes)
            #expect(job.progress.elapsedTime == elapsed)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle job errors", tags: ["error", "job"])
    func testErrorHandling() throws {
        // Given: Job with different error scenarios
        let context = TestContext()
        let testCases: [(BackupError?, BackupJobStatus)] = [
            // No error
            (nil, .completed),
            
            // Network error
            (MockData.Error.networkError, .failed),
            
            // Permission error
            (MockData.Error.permissionError, .failed),
            
            // Repository error
            (MockData.Error.repositoryError, .failed)
        ]
        
        // When/Then: Test error handling
        for (error, expectedStatus) in testCases {
            var job = context.createJob(status: .running)
            job.error = error
            job.status = expectedStatus
            
            #expect(job.error == error)
            #expect(job.status == expectedStatus)
            if error != nil {
                #expect(job.hasError)
            } else {
                #expect(!job.hasError)
            }
        }
    }
    
    // MARK: - Retry Tests
    
    @Test("Handle job retries", tags: ["retry", "job"])
    func testRetries() throws {
        // Given: Job with retry attempts
        let context = TestContext()
        var job = context.createJob()
        let maxRetries = 3
        
        // When/Then: Test retry handling
        for i in 0..<maxRetries {
            #expect(job.canRetry(maxAttempts: maxRetries))
            job.retryCount += 1
            #expect(job.retryCount == i + 1)
        }
        
        #expect(!job.canRetry(maxAttempts: maxRetries))
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle edge cases", tags: ["edge", "job"])
    func testEdgeCases() throws {
        // Given: Edge case scenarios
        let context = TestContext()
        
        // Test invalid status transition
        var invalidJob = context.createJob(status: .completed)
        invalidJob.status = .running
        #expect(invalidJob.status == .completed)
        
        // Test maximum retries
        var maxRetryJob = context.createJob(retryCount: Int.max)
        #expect(!maxRetryJob.canRetry(maxAttempts: 3))
        
        // Test zero progress
        let zeroProgressJob = context.createJob(progress: MockData.Progress.zeroProgress)
        #expect(zeroProgressJob.progress.percentage == 0)
        #expect(zeroProgressJob.progress.bytesProcessed == 0)
        #expect(zeroProgressJob.progress.elapsedTime == 0)
        
        // Test invalid dates
        let invalidDatesJob = context.createJob(
            startTime: Date(),
            endTime: Date().addingTimeInterval(-300)
        )
        #expect(!invalidDatesJob.isValid())
    }
}

// MARK: - Mock Implementations

/// Mock implementation of UserDefaults for testing
final class MockUserDefaults: UserDefaults {
    var storage: [String: Any] = [:]
    
    override func set(_ value: Any?, forKey defaultName: String) {
        if let value = value {
            storage[defaultName] = value
        } else {
            storage.removeValue(forKey: defaultName)
        }
    }
    
    override func object(forKey defaultName: String) -> Any? {
        storage[defaultName]
    }
    
    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
    
    func reset() {
        storage.removeAll()
    }
}

/// Mock implementation of NotificationCenter for testing
final class MockNotificationCenter: NotificationCenter {
    var postCalled = false
    var lastNotification: Notification?
    
    override func post(_ notification: Notification) {
        postCalled = true
        lastNotification = notification
    }
    
    func reset() {
        postCalled = false
        lastNotification = nil
    }
}

/// Mock implementation of DateProvider for testing
final class MockDateProvider: DateProvider {
    var currentDate: Date = Date()
    
    func now() -> Date {
        currentDate
    }
    
    func setDate(_ date: Date) {
        currentDate = date
    }
    
    func reset() {
        currentDate = Date()
    }
}

/// Mock implementation of ResticService for testing
final class MockResticService: ResticServiceProtocol {
    var backupCalled = false
    var lastBackupConfiguration: BackupConfiguration?
    var shouldFail = false
    
    func backup(_ configuration: BackupConfiguration) async throws {
        backupCalled = true
        lastBackupConfiguration = configuration
        if shouldFail {
            throw MockData.Error.backupError
        }
    }
    
    func reset() {
        backupCalled = false
        lastBackupConfiguration = nil
        shouldFail = false
    }
}
