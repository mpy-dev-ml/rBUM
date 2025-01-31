//
//  BackupNotificationTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupNotification functionality
struct BackupNotificationTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let notificationCenter: MockNotificationCenter
        let dateProvider: MockDateProvider
        let soundPlayer: MockSoundPlayer
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.notificationCenter = MockNotificationCenter()
            self.dateProvider = MockDateProvider()
            self.soundPlayer = MockSoundPlayer()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            notificationCenter.reset()
            dateProvider.reset()
            soundPlayer.reset()
        }
        
        /// Create test notification manager
        func createNotificationManager() -> BackupNotificationManager {
            BackupNotificationManager(
                userDefaults: userDefaults,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider,
                soundPlayer: soundPlayer
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup notification manager", tags: ["init", "notification"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating notification manager
        let manager = context.createNotificationManager()
        
        // Then: Manager is configured correctly
        #expect(manager.isEnabled)
        #expect(manager.soundEnabled)
        #expect(!manager.suppressDuplicates)
        #expect(manager.duplicateThreshold == 300) // 5 minutes
        #expect(manager.notifications.isEmpty)
    }
    
    // MARK: - Notification Tests
    
    @Test("Test notification handling", tags: ["notification", "core"])
    func testNotificationHandling() throws {
        // Given: Notification manager
        let context = TestContext()
        let manager = context.createNotificationManager()
        
        let notifications = MockData.Notification.validNotifications
        
        // Test posting notifications
        for notification in notifications {
            try manager.post(notification)
            
            // Verify notification was posted
            #expect(context.notificationCenter.postCalled)
            #expect(manager.notifications.contains(notification))
            
            if notification.playSound {
                #expect(context.soundPlayer.playCalled)
            }
            
            context.reset()
        }
        
        // Test notification history
        #expect(manager.notifications.count == notifications.count)
        
        // Test notification retrieval
        let latestNotification = manager.getLatestNotification()
        #expect(latestNotification == notifications.last)
    }
    
    // MARK: - Duplicate Handling Tests
    
    @Test("Test duplicate notification handling", tags: ["notification", "duplicate"])
    func testDuplicateHandling() throws {
        // Given: Notification manager with duplicate suppression
        let context = TestContext()
        let manager = context.createNotificationManager()
        manager.suppressDuplicates = true
        manager.duplicateThreshold = 60 // 1 minute
        
        let notification = MockData.Notification.validNotifications[0]
        
        // Test initial notification
        try manager.post(notification)
        #expect(context.notificationCenter.postCalled)
        
        // Test duplicate within threshold
        context.reset()
        try manager.post(notification)
        #expect(!context.notificationCenter.postCalled)
        
        // Test after threshold
        context.reset()
        context.dateProvider.advanceTime(by: 120) // 2 minutes
        try manager.post(notification)
        #expect(context.notificationCenter.postCalled)
    }
    
    // MARK: - Priority Tests
    
    @Test("Test notification priorities", tags: ["notification", "priority"])
    func testPriorities() throws {
        // Given: Notification manager
        let context = TestContext()
        let manager = context.createNotificationManager()
        
        // Test different priority notifications
        let priorities = MockData.Notification.priorities
        for priority in priorities {
            let notification = BackupNotification(
                title: "Test",
                message: "Test Message",
                type: .info,
                priority: priority
            )
            
            try manager.post(notification)
            
            // Verify priority handling
            switch priority {
            case .high:
                #expect(context.notificationCenter.postCalled)
                #expect(context.soundPlayer.playCalled)
            case .normal:
                #expect(context.notificationCenter.postCalled)
                #expect(!context.soundPlayer.playCalled)
            case .low:
                #expect(!context.notificationCenter.postCalled)
                #expect(!context.soundPlayer.playCalled)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Sound Tests
    
    @Test("Test notification sounds", tags: ["notification", "sound"])
    func testSounds() throws {
        // Given: Notification manager
        let context = TestContext()
        let manager = context.createNotificationManager()
        
        let notification = MockData.Notification.validNotifications[0]
        
        // Test with sound enabled
        manager.soundEnabled = true
        try manager.post(notification)
        #expect(context.soundPlayer.playCalled)
        
        // Test with sound disabled
        context.reset()
        manager.soundEnabled = false
        try manager.post(notification)
        #expect(!context.soundPlayer.playCalled)
        
        // Test custom sounds
        context.reset()
        manager.soundEnabled = true
        let customSoundNotification = BackupNotification(
            title: "Test",
            message: "Test Message",
            type: .info,
            sound: "custom.wav"
        )
        try manager.post(customSoundNotification)
        #expect(context.soundPlayer.lastPlayedSound == "custom.wav")
    }
    
    // MARK: - Persistence Tests
    
    @Test("Test notification persistence", tags: ["notification", "persistence"])
    func testPersistence() throws {
        // Given: Notification manager with notifications
        let context = TestContext()
        let manager = context.createNotificationManager()
        
        let notifications = MockData.Notification.validNotifications
        for notification in notifications {
            try manager.post(notification)
        }
        
        // When: Saving state
        try manager.save()
        
        // Then: State is persisted
        let loadedManager = context.createNotificationManager()
        try loadedManager.load()
        
        #expect(loadedManager.isEnabled == manager.isEnabled)
        #expect(loadedManager.soundEnabled == manager.soundEnabled)
        #expect(loadedManager.suppressDuplicates == manager.suppressDuplicates)
        #expect(loadedManager.duplicateThreshold == manager.duplicateThreshold)
        #expect(loadedManager.notifications == manager.notifications)
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle notification edge cases", tags: ["notification", "edge"])
    func testEdgeCases() throws {
        // Given: Notification manager
        let context = TestContext()
        let manager = context.createNotificationManager()
        
        // Test empty notification
        do {
            try manager.post(BackupNotification(title: "", message: "", type: .info))
            throw TestFailure("Expected error for empty notification")
        } catch {
            // Expected error
        }
        
        // Test disabled manager
        manager.isEnabled = false
        try manager.post(MockData.Notification.validNotifications[0])
        #expect(!context.notificationCenter.postCalled)
        
        // Test invalid threshold
        manager.duplicateThreshold = -1
        #expect(manager.duplicateThreshold == 0)
        
        // Test notification limit
        for _ in 0..<1000 {
            try manager.post(MockData.Notification.validNotifications[0])
        }
        #expect(manager.notifications.count <= 100) // Maximum history size
    }
    
    // MARK: - Performance Tests
    
    @Test("Test notification performance", tags: ["notification", "performance"])
    func testPerformance() throws {
        // Given: Notification manager
        let context = TestContext()
        let manager = context.createNotificationManager()
        
        // Test rapid notifications
        let startTime = context.dateProvider.now()
        for i in 0..<1000 {
            try manager.post(BackupNotification(
                title: "Test \(i)",
                message: "Test Message",
                type: .info
            ))
        }
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test notification lookup performance
        let lookupStartTime = context.dateProvider.now()
        for _ in 0..<1000 {
            _ = manager.getLatestNotification()
        }
        let lookupEndTime = context.dateProvider.now()
        
        let lookupInterval = lookupEndTime.timeIntervalSince(lookupStartTime)
        #expect(lookupInterval < 0.1) // Lookup should be fast
    }
}

// MARK: - Mock Sound Player

/// Mock implementation of SoundPlayer for testing
final class MockSoundPlayer: SoundPlayerProtocol {
    private(set) var playCalled: Bool = false
    private(set) var lastPlayedSound: String?
    
    func play(_ sound: String?) {
        playCalled = true
        lastPlayedSound = sound
    }
    
    func reset() {
        playCalled = false
        lastPlayedSound = nil
    }
}
