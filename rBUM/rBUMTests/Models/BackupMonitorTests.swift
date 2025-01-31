//
//  BackupMonitorTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupMonitor functionality
struct BackupMonitorTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let fileManager: MockFileManager
        let dateProvider: MockDateProvider
        let notificationCenter: MockNotificationCenter
        let fsEventStream: MockFSEventStream
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.fileManager = MockFileManager()
            self.dateProvider = MockDateProvider()
            self.notificationCenter = MockNotificationCenter()
            self.fsEventStream = MockFSEventStream()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            fileManager.reset()
            dateProvider.reset()
            notificationCenter.reset()
            fsEventStream.reset()
        }
        
        /// Create test monitor
        func createMonitor() -> BackupMonitor {
            BackupMonitor(
                userDefaults: userDefaults,
                fileManager: fileManager,
                dateProvider: dateProvider,
                notificationCenter: notificationCenter,
                fsEventStream: fsEventStream
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup monitor", tags: ["init", "monitor"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating monitor
        let monitor = context.createMonitor()
        
        // Then: Monitor is configured correctly
        #expect(!monitor.isActive)
        #expect(monitor.watchedPaths.isEmpty)
        #expect(monitor.excludedPaths.isEmpty)
    }
    
    // MARK: - Path Management Tests
    
    @Test("Test path management", tags: ["path", "monitor"])
    func testPathManagement() throws {
        // Given: Monitor and test data
        let context = TestContext()
        let monitor = context.createMonitor()
        
        let paths = MockData.Path.validPaths
        let excludedPaths = MockData.Path.excludedPaths
        
        // When: Adding paths
        for path in paths {
            try monitor.addPath(path)
        }
        
        // Then: Paths are watched
        #expect(monitor.watchedPaths.count == paths.count)
        for path in paths {
            #expect(monitor.isWatching(path))
        }
        
        // When: Adding excluded paths
        for path in excludedPaths {
            try monitor.addExcludedPath(path)
        }
        
        // Then: Paths are excluded
        #expect(monitor.excludedPaths.count == excludedPaths.count)
        for path in excludedPaths {
            #expect(monitor.isExcluded(path))
        }
        
        // When: Removing paths
        try monitor.removePath(paths[0])
        try monitor.removeExcludedPath(excludedPaths[0])
        
        // Then: Paths are removed
        #expect(!monitor.isWatching(paths[0]))
        #expect(!monitor.isExcluded(excludedPaths[0]))
    }
    
    // MARK: - Monitoring Tests
    
    @Test("Monitor file system events", tags: ["monitor", "events"])
    func testFileSystemMonitoring() async throws {
        // Given: Monitor with test paths
        let context = TestContext()
        let monitor = context.createMonitor()
        let paths = MockData.Backup.validSourcePaths
        
        // When: Starting monitoring
        try await monitor.startMonitoring(paths: paths)
        
        // Then: Monitoring is active
        #expect(context.fsEventStream.isStarted)
        #expect(monitor.isMonitoring)
        #expect(!monitor.showError)
        #expect(monitor.monitoredPaths == Set(paths))
    }
    
    @Test("Handle monitoring errors", tags: ["monitor", "error"])
    func testMonitoringErrors() async throws {
        // Given: Monitor with failing stream
        let context = TestContext()
        let monitor = context.createMonitor()
        context.fsEventStream.shouldFail = true
        context.fsEventStream.error = MockData.Error.monitoringError
        
        // When: Starting monitoring
        try await monitor.startMonitoring(paths: MockData.Backup.validSourcePaths)
        
        // Then: Error is handled properly
        #expect(!context.fsEventStream.isStarted)
        #expect(!monitor.isMonitoring)
        #expect(monitor.showError)
        #expect(monitor.error as? MockData.Error == MockData.Error.monitoringError)
    }
    
    @Test("Filter file system events", tags: ["monitor", "filter"])
    func testEventFiltering() async throws {
        // Given: Monitor with test paths
        let context = TestContext()
        let monitor = context.createMonitor()
        let paths = MockData.Backup.validSourcePaths
        let events = MockData.FSEvent.validEvents
        
        try await monitor.startMonitoring(paths: paths)
        
        // When: Processing events
        monitor.processEvents(events)
        
        // Then: Events are filtered correctly
        #expect(context.notificationCenter.postNotificationCalled)
        #expect(monitor.lastEventTime == context.dateProvider.now)
        #expect(!monitor.showError)
    }
    
    @Test("Handle path changes", tags: ["monitor", "paths"])
    func testPathChanges() async throws {
        // Given: Monitor with initial paths
        let context = TestContext()
        let monitor = context.createMonitor()
        let initialPaths = MockData.Backup.validSourcePaths
        let newPaths = MockData.Backup.updatedSourcePaths
        
        try await monitor.startMonitoring(paths: initialPaths)
        
        // When: Updating monitored paths
        try await monitor.updatePaths(newPaths)
        
        // Then: Paths are updated correctly
        #expect(monitor.monitoredPaths == Set(newPaths))
        #expect(context.fsEventStream.isRestarted)
        #expect(!monitor.showError)
    }
    
    @Test("Stop monitoring", tags: ["monitor", "stop"])
    func testStopMonitoring() async throws {
        // Given: Active monitor
        let context = TestContext()
        let monitor = context.createMonitor()
        try await monitor.startMonitoring(paths: MockData.Backup.validSourcePaths)
        
        // When: Stopping monitoring
        await monitor.stopMonitoring()
        
        // Then: Monitoring is stopped
        #expect(!context.fsEventStream.isStarted)
        #expect(!monitor.isMonitoring)
        #expect(monitor.monitoredPaths.isEmpty)
        #expect(!monitor.showError)
    }
    
    // MARK: - Performance Tests
    
    @Test("Test monitor performance", tags: ["performance", "monitor"])
    func testPerformance() throws {
        // Given: Monitor
        let context = TestContext()
        let monitor = context.createMonitor()
        
        // Test bulk path addition
        let startTime = context.dateProvider.now()
        for i in 0..<1000 {
            try monitor.addPath("/test/path/\(i)")
        }
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test event processing performance
        try monitor.start()
        
        let eventStartTime = context.dateProvider.now()
        for _ in 0..<100 {
            context.fsEventStream.simulateEvents(for: "/test/path/0")
        }
        let eventEndTime = context.dateProvider.now()
        
        let eventInterval = eventEndTime.timeIntervalSince(eventStartTime)
        #expect(eventInterval < 0.1) // Event processing should be fast
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle monitor edge cases", tags: ["edge", "monitor"])
    func testEdgeCases() throws {
        // Given: Monitor
        let context = TestContext()
        let monitor = context.createMonitor()
        
        // Test invalid paths
        do {
            try monitor.addPath("")
            throw TestFailure("Expected error for empty path")
        } catch {
            // Expected error
        }
        
        do {
            try monitor.addPath("relative/path")
            throw TestFailure("Expected error for relative path")
        } catch {
            // Expected error
        }
        
        // Test duplicate paths
        let path = MockData.Path.validPaths[0]
        try monitor.addPath(path)
        do {
            try monitor.addPath(path)
            throw TestFailure("Expected error for duplicate path")
        } catch {
            // Expected error
        }
        
        // Test starting without paths
        do {
            try monitor.start()
            throw TestFailure("Expected error when starting without paths")
        } catch {
            // Expected error
        }
        
        // Test stopping when not started
        monitor.stop()
        #expect(!monitor.isActive)
    }
    
    // MARK: - Persistence Tests
    
    @Test("Test monitor persistence", tags: ["persistence", "monitor"])
    func testPersistence() throws {
        // Given: Monitor with configuration
        let context = TestContext()
        let monitor = context.createMonitor()
        
        let paths = MockData.Path.validPaths
        let excludedPaths = MockData.Path.excludedPaths
        
        for path in paths {
            try monitor.addPath(path)
        }
        for path in excludedPaths {
            try monitor.addExcludedPath(path)
        }
        
        // When: Saving configuration
        try monitor.save()
        
        // Then: Configuration is persisted
        let loadedMonitor = context.createMonitor()
        try loadedMonitor.load()
        
        #expect(loadedMonitor.watchedPaths == monitor.watchedPaths)
        #expect(loadedMonitor.excludedPaths == monitor.excludedPaths)
    }
}

// MARK: - Mock FSEventStream

/// Mock implementation of FSEventStream for testing
final class MockFSEventStream: FSEventStreamProtocol {
    private(set) var isStarted: Bool = false
    private var eventHandler: ((String) -> Void)?
    private(set) var isRestarted: Bool = false
    var shouldFail: Bool = false
    var error: Error?
    
    func start(paths: [String], handler: @escaping (String) -> Void) throws {
        if shouldFail {
            throw error!
        }
        isStarted = true
        eventHandler = handler
    }
    
    func stop() {
        isStarted = false
        eventHandler = nil
    }
    
    func restart() {
        isRestarted = true
    }
    
    func simulateEvents(for path: String) {
        eventHandler?(path)
    }
    
    func reset() {
        isStarted = false
        eventHandler = nil
        isRestarted = false
        shouldFail = false
        error = nil
    }
}
