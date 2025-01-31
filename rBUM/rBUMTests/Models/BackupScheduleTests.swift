//
//  BackupScheduleTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupSchedule functionality
struct BackupScheduleTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let dateProvider: MockDateProvider
        let notificationCenter: MockNotificationCenter
        let userDefaults: MockUserDefaults
        
        init() {
            self.dateProvider = MockDateProvider()
            self.notificationCenter = MockNotificationCenter()
            self.userDefaults = MockUserDefaults()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            dateProvider.reset()
            notificationCenter.reset()
            userDefaults.reset()
        }
        
        /// Create test schedule manager
        func createScheduleManager() -> BackupScheduleManager {
            BackupScheduleManager(
                dateProvider: dateProvider,
                notificationCenter: notificationCenter,
                userDefaults: userDefaults
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize schedule manager", tags: ["init", "schedule"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating schedule manager
        let manager = context.createScheduleManager()
        
        // Then: Manager is properly configured
        #expect(manager.schedules.isEmpty)
        #expect(!manager.isRunning)
    }
    
    // MARK: - Schedule Creation Tests
    
    @Test("Test schedule creation", tags: ["schedule", "create"])
    func testScheduleCreation() throws {
        // Given: Schedule manager
        let context = TestContext()
        let manager = context.createScheduleManager()
        
        let schedules = MockData.Schedule.validSchedules
        
        // Test schedule creation
        for schedule in schedules {
            try manager.createSchedule(schedule)
            #expect(manager.schedules.contains(schedule))
            #expect(context.notificationCenter.postNotificationCalled)
            #expect(context.userDefaults.setValueCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Schedule Update Tests
    
    @Test("Test schedule updates", tags: ["schedule", "update"])
    func testScheduleUpdates() throws {
        // Given: Schedule manager with schedules
        let context = TestContext()
        let manager = context.createScheduleManager()
        
        let schedules = MockData.Schedule.updateSchedules
        
        // Add initial schedules
        for schedule in schedules {
            try manager.createSchedule(schedule)
        }
        
        // Test schedule updates
        for schedule in schedules {
            var updatedSchedule = schedule
            updatedSchedule.interval = .weekly
            try manager.updateSchedule(updatedSchedule)
            
            #expect(manager.schedules.contains(updatedSchedule))
            #expect(!manager.schedules.contains(schedule))
            #expect(context.notificationCenter.postNotificationCalled)
            #expect(context.userDefaults.setValueCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Schedule Deletion Tests
    
    @Test("Test schedule deletion", tags: ["schedule", "delete"])
    func testScheduleDeletion() throws {
        // Given: Schedule manager with schedules
        let context = TestContext()
        let manager = context.createScheduleManager()
        
        let schedules = MockData.Schedule.validSchedules
        
        // Add schedules
        for schedule in schedules {
            try manager.createSchedule(schedule)
        }
        
        // Test schedule deletion
        for schedule in schedules {
            try manager.deleteSchedule(schedule.id)
            #expect(!manager.schedules.contains(schedule))
            #expect(context.notificationCenter.postNotificationCalled)
            #expect(context.userDefaults.setValueCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Schedule Execution Tests
    
    @Test("Test schedule execution", tags: ["schedule", "execute"])
    func testScheduleExecution() throws {
        // Given: Schedule manager with schedules
        let context = TestContext()
        let manager = context.createScheduleManager()
        
        let schedules = MockData.Schedule.executionSchedules
        
        // Add schedules
        for schedule in schedules {
            try manager.createSchedule(schedule)
        }
        
        // Test schedule execution
        for schedule in schedules {
            // Set current time to trigger schedule
            context.dateProvider.currentDate = schedule.nextRunTime
            
            try manager.checkSchedules()
            #expect(context.notificationCenter.postNotificationCalled)
            let notification = context.notificationCenter.lastPostedNotification
            #expect(notification?.name == .backupScheduleTriggered)
            
            context.reset()
        }
    }
    
    // MARK: - Next Run Time Tests
    
    @Test("Test next run time calculations", tags: ["schedule", "time"])
    func testNextRunTimeCalculations() throws {
        // Given: Schedule manager
        let context = TestContext()
        let manager = context.createScheduleManager()
        
        let schedules = MockData.Schedule.timeCalculationSchedules
        
        // Test next run time calculations
        for schedule in schedules {
            let nextRun = try manager.calculateNextRunTime(schedule)
            
            switch schedule.interval {
            case .hourly:
                let expectedInterval: TimeInterval = 3600
                let difference = nextRun.timeIntervalSince(context.dateProvider.now())
                #expect(abs(difference - expectedInterval) < 1.0)
                
            case .daily:
                let expectedInterval: TimeInterval = 86400
                let difference = nextRun.timeIntervalSince(context.dateProvider.now())
                #expect(abs(difference - expectedInterval) < 1.0)
                
            case .weekly:
                let expectedInterval: TimeInterval = 604800
                let difference = nextRun.timeIntervalSince(context.dateProvider.now())
                #expect(abs(difference - expectedInterval) < 1.0)
                
            case .monthly:
                // Monthly interval varies, just ensure it's in the future
                #expect(nextRun > context.dateProvider.now())
            }
            
            context.reset()
        }
    }
    
    // MARK: - Persistence Tests
    
    @Test("Test schedule persistence", tags: ["schedule", "persistence"])
    func testPersistence() throws {
        // Given: Schedule manager with schedules
        let context = TestContext()
        let manager = context.createScheduleManager()
        
        let schedules = MockData.Schedule.validSchedules
        
        // Add schedules
        for schedule in schedules {
            try manager.createSchedule(schedule)
        }
        
        // When: Saving state
        try manager.save()
        
        // Then: State is persisted
        let loadedManager = context.createScheduleManager()
        try loadedManager.load()
        
        #expect(loadedManager.schedules.count == schedules.count)
        for schedule in schedules {
            #expect(loadedManager.schedules.contains(schedule))
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test schedule error handling", tags: ["schedule", "error"])
    func testErrorHandling() throws {
        // Given: Schedule manager
        let context = TestContext()
        let manager = context.createScheduleManager()
        
        let schedules = MockData.Schedule.errorSchedules
        
        // Test error handling
        for schedule in schedules {
            do {
                try manager.createSchedule(schedule)
                #expect(false, "Expected error for invalid schedule")
            } catch {
                // Expected error
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .backupScheduleError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle schedule edge cases", tags: ["schedule", "edge"])
    func testEdgeCases() throws {
        // Given: Schedule manager
        let context = TestContext()
        let manager = context.createScheduleManager()
        
        // Test invalid schedule ID
        do {
            try manager.deleteSchedule(UUID())
            throw TestFailure("Expected error for invalid schedule ID")
        } catch {
            // Expected error
        }
        
        // Test duplicate schedule
        let schedule = MockData.Schedule.validSchedules[0]
        try manager.createSchedule(schedule)
        
        do {
            try manager.createSchedule(schedule)
            throw TestFailure("Expected error for duplicate schedule")
        } catch {
            // Expected error
        }
        
        // Test past next run time
        var pastSchedule = schedule
        pastSchedule.nextRunTime = context.dateProvider.now().addingTimeInterval(-3600)
        try manager.createSchedule(pastSchedule)
        try manager.checkSchedules()
        
        // Should update next run time
        let updatedSchedule = manager.schedules.first { $0.id == pastSchedule.id }
        #expect(updatedSchedule?.nextRunTime ?? Date() > context.dateProvider.now())
    }
    
    // MARK: - Performance Tests
    
    @Test("Test schedule performance", tags: ["schedule", "performance"])
    func testPerformance() throws {
        // Given: Schedule manager
        let context = TestContext()
        let manager = context.createScheduleManager()
        
        // Test schedule checks performance
        let startTime = context.dateProvider.now()
        
        // Add many schedules
        for _ in 0..<100 {
            var schedule = MockData.Schedule.validSchedules[0]
            schedule.id = UUID()
            try manager.createSchedule(schedule)
        }
        
        // Check schedules repeatedly
        for _ in 0..<100 {
            try manager.checkSchedules()
        }
        
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test next run time calculation performance
        let calcStartTime = context.dateProvider.now()
        let schedule = MockData.Schedule.validSchedules[0]
        
        for _ in 0..<1000 {
            _ = try manager.calculateNextRunTime(schedule)
        }
        
        let calcEndTime = context.dateProvider.now()
        
        let calcInterval = calcEndTime.timeIntervalSince(calcStartTime)
        #expect(calcInterval < 0.1) // Calculations should be fast
    }
}

// MARK: - Mock User Defaults

/// Mock implementation of UserDefaults for testing
final class MockUserDefaults: UserDefaultsProtocol {
    private(set) var setValueCalled = false
    private(set) var getValueCalled = false
    private var storage: [String: Any] = [:]
    
    func setValue(_ value: Any?, forKey key: String) {
        setValueCalled = true
        storage[key] = value
    }
    
    func value(forKey key: String) -> Any? {
        getValueCalled = true
        return storage[key]
    }
    
    func reset() {
        setValueCalled = false
        getValueCalled = false
        storage.removeAll()
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
