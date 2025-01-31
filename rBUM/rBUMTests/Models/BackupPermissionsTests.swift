//
//  BackupPermissionsTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupPermissions functionality
struct BackupPermissionsTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let fileManager: MockFileManager
        let securityService: MockSecurityService
        let notificationCenter: MockNotificationCenter
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.fileManager = MockFileManager()
            self.securityService = MockSecurityService()
            self.notificationCenter = MockNotificationCenter()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            fileManager.reset()
            securityService.reset()
            notificationCenter.reset()
        }
        
        /// Create test permissions manager
        func createPermissionsManager() -> BackupPermissionsManager {
            BackupPermissionsManager(
                userDefaults: userDefaults,
                fileManager: fileManager,
                securityService: securityService,
                notificationCenter: notificationCenter
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup permissions manager", tags: ["init", "permissions"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating permissions manager
        let manager = context.createPermissionsManager()
        
        // Then: Manager is configured correctly
        #expect(manager.permissions.isEmpty)
        #expect(!manager.isFullDiskAccessGranted)
        #expect(!manager.isAutomationEnabled)
    }
    
    // MARK: - Permission Tests
    
    @Test("Test permission handling", tags: ["permissions", "core"])
    func testPermissionHandling() throws {
        // Given: Permissions manager
        let context = TestContext()
        let manager = context.createPermissionsManager()
        
        let paths = MockData.Path.validPaths
        
        // Test permission requests
        for path in paths {
            try manager.requestPermission(for: path)
            
            // Verify permission request
            #expect(context.securityService.requestPermissionCalled)
            #expect(manager.hasPermission(for: path))
            
            context.reset()
        }
        
        // Test permission revocation
        try manager.revokePermission(for: paths[0])
        #expect(!manager.hasPermission(for: paths[0]))
        #expect(context.securityService.revokePermissionCalled)
    }
    
    // MARK: - Full Disk Access Tests
    
    @Test("Test full disk access", tags: ["permissions", "disk"])
    func testFullDiskAccess() throws {
        // Given: Permissions manager
        let context = TestContext()
        let manager = context.createPermissionsManager()
        
        // Test full disk access request
        try manager.requestFullDiskAccess()
        #expect(context.securityService.requestFullDiskAccessCalled)
        
        // Simulate granted access
        context.securityService.simulateFullDiskAccess(granted: true)
        #expect(manager.isFullDiskAccessGranted)
        
        // Test access check
        let hasAccess = try manager.checkFullDiskAccess()
        #expect(hasAccess)
        #expect(context.securityService.checkFullDiskAccessCalled)
    }
    
    // MARK: - Automation Tests
    
    @Test("Test automation permissions", tags: ["permissions", "automation"])
    func testAutomation() throws {
        // Given: Permissions manager
        let context = TestContext()
        let manager = context.createPermissionsManager()
        
        // Test automation request
        try manager.requestAutomation()
        #expect(context.securityService.requestAutomationCalled)
        
        // Simulate enabled automation
        context.securityService.simulateAutomation(enabled: true)
        #expect(manager.isAutomationEnabled)
        
        // Test automation check
        let isEnabled = try manager.checkAutomation()
        #expect(isEnabled)
        #expect(context.securityService.checkAutomationCalled)
    }
    
    // MARK: - Sandbox Tests
    
    @Test("Test sandbox permissions", tags: ["permissions", "sandbox"])
    func testSandbox() throws {
        // Given: Permissions manager
        let context = TestContext()
        let manager = context.createPermissionsManager()
        
        let bookmarks = MockData.Permission.validBookmarks
        
        // Test bookmark creation
        for (path, data) in bookmarks {
            try manager.createBookmark(for: path)
            #expect(context.securityService.createBookmarkCalled)
            #expect(manager.hasBookmark(for: path))
            
            // Verify bookmark data
            let bookmark = try manager.getBookmark(for: path)
            #expect(bookmark == data)
            
            context.reset()
        }
        
        // Test bookmark resolution
        let resolvedPath = try manager.resolveBookmark(bookmarks.first!.value)
        #expect(resolvedPath == bookmarks.first!.key)
        #expect(context.securityService.resolveBookmarkCalled)
    }
    
    // MARK: - Security Scope Tests
    
    @Test("Test security scoped access", tags: ["permissions", "security"])
    func testSecurityScope() throws {
        // Given: Permissions manager
        let context = TestContext()
        let manager = context.createPermissionsManager()
        
        let paths = MockData.Path.validPaths
        
        // Test security scope access
        for path in paths {
            let token = try manager.startSecurityScope(for: path)
            #expect(token != nil)
            #expect(context.securityService.startAccessCalled)
            
            // Test scope release
            try manager.endSecurityScope(token!)
            #expect(context.securityService.endAccessCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Persistence Tests
    
    @Test("Test permissions persistence", tags: ["permissions", "persistence"])
    func testPersistence() throws {
        // Given: Permissions manager with permissions
        let context = TestContext()
        let manager = context.createPermissionsManager()
        
        let paths = MockData.Path.validPaths
        for path in paths {
            try manager.requestPermission(for: path)
        }
        
        // When: Saving state
        try manager.save()
        
        // Then: State is persisted
        let loadedManager = context.createPermissionsManager()
        try loadedManager.load()
        
        for path in paths {
            #expect(loadedManager.hasPermission(for: path))
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle permissions edge cases", tags: ["permissions", "edge"])
    func testEdgeCases() throws {
        // Given: Permissions manager
        let context = TestContext()
        let manager = context.createPermissionsManager()
        
        // Test invalid paths
        do {
            try manager.requestPermission(for: "")
            throw TestFailure("Expected error for empty path")
        } catch {
            // Expected error
        }
        
        // Test non-existent paths
        do {
            try manager.requestPermission(for: "/non/existent/path")
            throw TestFailure("Expected error for non-existent path")
        } catch {
            // Expected error
        }
        
        // Test invalid bookmarks
        do {
            try manager.resolveBookmark(Data())
            throw TestFailure("Expected error for invalid bookmark")
        } catch {
            // Expected error
        }
        
        // Test invalid security scope token
        do {
            try manager.endSecurityScope("invalid-token")
            throw TestFailure("Expected error for invalid token")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test permissions performance", tags: ["permissions", "performance"])
    func testPerformance() throws {
        // Given: Permissions manager
        let context = TestContext()
        let manager = context.createPermissionsManager()
        
        // Test rapid permission requests
        let startTime = context.dateProvider.now()
        for i in 0..<1000 {
            try manager.requestPermission(for: "/test/path/\(i)")
        }
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test permission check performance
        let checkStartTime = context.dateProvider.now()
        for i in 0..<1000 {
            _ = manager.hasPermission(for: "/test/path/\(i)")
        }
        let checkEndTime = context.dateProvider.now()
        
        let checkInterval = checkEndTime.timeIntervalSince(checkStartTime)
        #expect(checkInterval < 0.1) // Permission checks should be fast
    }
}

// MARK: - Mock Security Service

/// Mock implementation of SecurityService for testing
final class MockSecurityService: SecurityServiceProtocol {
    private(set) var requestPermissionCalled = false
    private(set) var revokePermissionCalled = false
    private(set) var requestFullDiskAccessCalled = false
    private(set) var checkFullDiskAccessCalled = false
    private(set) var requestAutomationCalled = false
    private(set) var checkAutomationCalled = false
    private(set) var createBookmarkCalled = false
    private(set) var resolveBookmarkCalled = false
    private(set) var startAccessCalled = false
    private(set) var endAccessCalled = false
    
    private var isFullDiskAccessGranted = false
    private var isAutomationEnabled = false
    
    func requestPermission(for path: String) throws {
        requestPermissionCalled = true
    }
    
    func revokePermission(for path: String) throws {
        revokePermissionCalled = true
    }
    
    func requestFullDiskAccess() throws {
        requestFullDiskAccessCalled = true
    }
    
    func checkFullDiskAccess() throws -> Bool {
        checkFullDiskAccessCalled = true
        return isFullDiskAccessGranted
    }
    
    func requestAutomation() throws {
        requestAutomationCalled = true
    }
    
    func checkAutomation() throws -> Bool {
        checkAutomationCalled = true
        return isAutomationEnabled
    }
    
    func createBookmark(for path: String) throws -> Data {
        createBookmarkCalled = true
        return Data()
    }
    
    func resolveBookmark(_ data: Data) throws -> String {
        resolveBookmarkCalled = true
        return ""
    }
    
    func startSecurityScope(for path: String) throws -> String {
        startAccessCalled = true
        return "test-token"
    }
    
    func endSecurityScope(_ token: String) throws {
        endAccessCalled = true
    }
    
    func simulateFullDiskAccess(granted: Bool) {
        isFullDiskAccessGranted = granted
    }
    
    func simulateAutomation(enabled: Bool) {
        isAutomationEnabled = enabled
    }
    
    func reset() {
        requestPermissionCalled = false
        revokePermissionCalled = false
        requestFullDiskAccessCalled = false
        checkFullDiskAccessCalled = false
        requestAutomationCalled = false
        checkAutomationCalled = false
        createBookmarkCalled = false
        resolveBookmarkCalled = false
        startAccessCalled = false
        endAccessCalled = false
        isFullDiskAccessGranted = false
        isAutomationEnabled = false
    }
}
