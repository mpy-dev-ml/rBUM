//
//  BackupSettingsTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupSettings functionality
struct BackupSettingsTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let notificationCenter: MockNotificationCenter
        let fileManager: MockFileManager
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.notificationCenter = MockNotificationCenter()
            self.fileManager = MockFileManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            notificationCenter.reset()
            fileManager.reset()
        }
        
        /// Create test settings
        func createSettings(
            maxConcurrentBackups: Int = 2,
            maxBackupAttempts: Int = 3,
            retryDelay: TimeInterval = 300,
            notifyOnSuccess: Bool = true,
            notifyOnFailure: Bool = true,
            notifyOnWarning: Bool = true,
            compressBackups: Bool = true,
            excludeHiddenFiles: Bool = true,
            excludeSystemFiles: Bool = true,
            excludeCaches: Bool = true,
            repository: Repository = MockData.Repository.validRepository
        ) -> BackupSettings {
            BackupSettings(
                maxConcurrentBackups: maxConcurrentBackups,
                maxBackupAttempts: maxBackupAttempts,
                retryDelay: retryDelay,
                notifyOnSuccess: notifyOnSuccess,
                notifyOnFailure: notifyOnFailure,
                notifyOnWarning: notifyOnWarning,
                compressBackups: compressBackups,
                excludeHiddenFiles: excludeHiddenFiles,
                excludeSystemFiles: excludeSystemFiles,
                excludeCaches: excludeCaches,
                repository: repository
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize with default values", tags: ["init", "settings"])
    func testDefaultInitialization() throws {
        // Given: Default settings parameters
        let context = TestContext()
        
        // When: Creating settings
        let settings = context.createSettings()
        
        // Then: Settings are configured correctly
        #expect(settings.maxConcurrentBackups == 2)
        #expect(settings.maxBackupAttempts == 3)
        #expect(settings.retryDelay == 300)
        #expect(settings.notifyOnSuccess)
        #expect(settings.notifyOnFailure)
        #expect(settings.notifyOnWarning)
        #expect(settings.compressBackups)
        #expect(settings.excludeHiddenFiles)
        #expect(settings.excludeSystemFiles)
        #expect(settings.excludeCaches)
    }
    
    @Test("Initialize with custom values", tags: ["init", "settings"])
    func testCustomInitialization() throws {
        // Given: Custom settings parameters
        let context = TestContext()
        
        // When: Creating settings
        let settings = context.createSettings(
            maxConcurrentBackups: 4,
            maxBackupAttempts: 5,
            retryDelay: 600,
            notifyOnSuccess: false,
            notifyOnFailure: true,
            notifyOnWarning: false,
            compressBackups: false,
            excludeHiddenFiles: false,
            excludeSystemFiles: false,
            excludeCaches: false
        )
        
        // Then: Settings are configured correctly
        #expect(settings.maxConcurrentBackups == 4)
        #expect(settings.maxBackupAttempts == 5)
        #expect(settings.retryDelay == 600)
        #expect(!settings.notifyOnSuccess)
        #expect(settings.notifyOnFailure)
        #expect(!settings.notifyOnWarning)
        #expect(!settings.compressBackups)
        #expect(!settings.excludeHiddenFiles)
        #expect(!settings.excludeSystemFiles)
        #expect(!settings.excludeCaches)
    }
    
    // MARK: - Persistence Tests
    
    @Test("Save and load settings", tags: ["persistence", "settings"])
    func testPersistence() throws {
        // Given: Settings with custom values
        let context = TestContext()
        let settings = context.createSettings(
            maxConcurrentBackups: 4,
            maxBackupAttempts: 5,
            retryDelay: 600,
            notifyOnSuccess: false,
            notifyOnFailure: true,
            notifyOnWarning: false,
            compressBackups: false,
            excludeHiddenFiles: false,
            excludeSystemFiles: false,
            excludeCaches: false
        )
        
        // When: Saving and loading settings
        settings.save(to: context.userDefaults)
        let loaded = BackupSettings.load(from: context.userDefaults)
        
        // Then: Loaded settings match original
        #expect(loaded?.maxConcurrentBackups == settings.maxConcurrentBackups)
        #expect(loaded?.maxBackupAttempts == settings.maxBackupAttempts)
        #expect(loaded?.retryDelay == settings.retryDelay)
        #expect(loaded?.notifyOnSuccess == settings.notifyOnSuccess)
        #expect(loaded?.notifyOnFailure == settings.notifyOnFailure)
        #expect(loaded?.notifyOnWarning == settings.notifyOnWarning)
        #expect(loaded?.compressBackups == settings.compressBackups)
        #expect(loaded?.excludeHiddenFiles == settings.excludeHiddenFiles)
        #expect(loaded?.excludeSystemFiles == settings.excludeSystemFiles)
        #expect(loaded?.excludeCaches == settings.excludeCaches)
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate settings", tags: ["validation", "settings"])
    func testValidation() throws {
        // Given: Settings with various configurations
        let context = TestContext()
        let testCases: [(BackupSettings, Bool)] = [
            // Valid settings
            (context.createSettings(
                maxConcurrentBackups: 2,
                maxBackupAttempts: 3,
                retryDelay: 300
            ), true),
            
            // Invalid max concurrent backups
            (context.createSettings(
                maxConcurrentBackups: 0,
                maxBackupAttempts: 3,
                retryDelay: 300
            ), false),
            
            // Invalid max backup attempts
            (context.createSettings(
                maxConcurrentBackups: 2,
                maxBackupAttempts: 0,
                retryDelay: 300
            ), false),
            
            // Invalid retry delay
            (context.createSettings(
                maxConcurrentBackups: 2,
                maxBackupAttempts: 3,
                retryDelay: -1
            ), false)
        ]
        
        // When/Then: Test validation
        for (settings, isValid) in testCases {
            #expect(settings.isValid() == isValid)
        }
    }
    
    // MARK: - Notification Tests
    
    @Test("Handle notifications", tags: ["notification", "settings"])
    func testNotifications() throws {
        // Given: Settings with different notification configurations
        let context = TestContext()
        let testCases: [(BackupSettings, NotificationType, Bool)] = [
            // Success notifications
            (context.createSettings(notifyOnSuccess: true), .success, true),
            (context.createSettings(notifyOnSuccess: false), .success, false),
            
            // Failure notifications
            (context.createSettings(notifyOnFailure: true), .failure, true),
            (context.createSettings(notifyOnFailure: false), .failure, false),
            
            // Warning notifications
            (context.createSettings(notifyOnWarning: true), .warning, true),
            (context.createSettings(notifyOnWarning: false), .warning, false)
        ]
        
        // When/Then: Test notification handling
        for (settings, type, shouldNotify) in testCases {
            #expect(settings.shouldNotify(for: type) == shouldNotify)
        }
    }
    
    // MARK: - Exclusion Tests
    
    @Test("Handle file exclusions", tags: ["exclusion", "settings"])
    func testExclusions() throws {
        // Given: Settings with different exclusion configurations
        let context = TestContext()
        let testCases: [(BackupSettings, String, Bool)] = [
            // Hidden files
            (context.createSettings(excludeHiddenFiles: true), ".hidden", true),
            (context.createSettings(excludeHiddenFiles: false), ".hidden", false),
            
            // System files
            (context.createSettings(excludeSystemFiles: true), "/var/log/system.log", true),
            (context.createSettings(excludeSystemFiles: false), "/var/log/system.log", false),
            
            // Cache files
            (context.createSettings(excludeCaches: true), "Library/Caches/test.cache", true),
            (context.createSettings(excludeCaches: false), "Library/Caches/test.cache", false),
            
            // Regular files
            (context.createSettings(), "document.txt", false)
        ]
        
        // When/Then: Test exclusion handling
        for (settings, path, shouldExclude) in testCases {
            #expect(settings.shouldExclude(path) == shouldExclude)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle edge cases", tags: ["edge", "settings"])
    func testEdgeCases() throws {
        // Given: Edge case scenarios
        let context = TestContext()
        
        // Test maximum values
        let maxSettings = context.createSettings(
            maxConcurrentBackups: Int.max,
            maxBackupAttempts: Int.max,
            retryDelay: TimeInterval.greatestFiniteMagnitude
        )
        #expect(!maxSettings.isValid())
        
        // Test minimum values
        let minSettings = context.createSettings(
            maxConcurrentBackups: Int.min,
            maxBackupAttempts: Int.min,
            retryDelay: TimeInterval.leastNormalMagnitude
        )
        #expect(!minSettings.isValid())
        
        // Test empty paths
        let settings = context.createSettings()
        #expect(!settings.shouldExclude(""))
        
        // Test nil UserDefaults
        let nilDefaults = MockUserDefaults()
        nilDefaults.removeObject(forKey: BackupSettings.defaultsKey)
        let loadedSettings = BackupSettings.load(from: nilDefaults)
        #expect(loadedSettings == nil)
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

/// Mock implementation of FileManager for testing
final class MockFileManager: FileManager {
    var files: [String: (isHidden: Bool, isSystem: Bool)] = [:]
    
    override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        files[path] != nil
    }
    
    func isHidden(_ path: String) -> Bool {
        files[path]?.isHidden ?? false
    }
    
    func isSystem(_ path: String) -> Bool {
        files[path]?.isSystem ?? false
    }
    
    func reset() {
        files.removeAll()
    }
}
