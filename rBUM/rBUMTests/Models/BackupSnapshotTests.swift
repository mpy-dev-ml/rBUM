//
//  BackupSnapshotTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupSnapshot functionality
struct BackupSnapshotTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let resticService: MockResticService
        let notificationCenter: MockNotificationCenter
        let dateProvider: MockDateProvider
        let fileManager: MockFileManager
        
        init() {
            self.resticService = MockResticService()
            self.notificationCenter = MockNotificationCenter()
            self.dateProvider = MockDateProvider()
            self.fileManager = MockFileManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            resticService.reset()
            notificationCenter.reset()
            dateProvider.reset()
            fileManager.reset()
        }
        
        /// Create test snapshot manager
        func createSnapshotManager() -> BackupSnapshotManager {
            BackupSnapshotManager(
                resticService: resticService,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider,
                fileManager: fileManager
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize snapshot manager", tags: ["init", "snapshot"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating snapshot manager
        let manager = context.createSnapshotManager()
        
        // Then: Manager is properly configured
        #expect(manager.isInitialized)
        #expect(manager.snapshotCount == 0)
    }
    
    // MARK: - Snapshot Creation Tests
    
    @Test("Test snapshot creation", tags: ["snapshot", "create"])
    func testSnapshotCreation() throws {
        // Given: Snapshot manager
        let context = TestContext()
        let manager = context.createSnapshotManager()
        
        let testData = MockData.Snapshot.creationData
        
        // Test snapshot creation
        for data in testData {
            // Create snapshot
            let snapshot = try manager.createSnapshot(data)
            #expect(snapshot.id != nil)
            #expect(context.resticService.createSnapshotCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify snapshot
            let verified = try manager.verifySnapshot(snapshot)
            #expect(verified)
            #expect(context.resticService.verifySnapshotCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Snapshot Listing Tests
    
    @Test("Test snapshot listing", tags: ["snapshot", "list"])
    func testSnapshotListing() throws {
        // Given: Snapshot manager
        let context = TestContext()
        let manager = context.createSnapshotManager()
        
        let repositories = MockData.Snapshot.validRepositories
        
        // Test snapshot listing
        for repository in repositories {
            // List snapshots
            let snapshots = try manager.listSnapshots(repository)
            #expect(!snapshots.isEmpty)
            #expect(context.resticService.listSnapshotsCalled)
            
            // Filter snapshots
            let filtered = try manager.filterSnapshots(snapshots, by: .latest)
            #expect(filtered.count <= snapshots.count)
            
            context.reset()
        }
    }
    
    // MARK: - Snapshot Restoration Tests
    
    @Test("Test snapshot restoration", tags: ["snapshot", "restore"])
    func testSnapshotRestoration() throws {
        // Given: Snapshot manager
        let context = TestContext()
        let manager = context.createSnapshotManager()
        
        let testCases = MockData.Snapshot.restorationData
        
        // Test snapshot restoration
        for testCase in testCases {
            // Restore snapshot
            try manager.restoreSnapshot(testCase.snapshot, to: testCase.path)
            #expect(context.resticService.restoreSnapshotCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify restoration
            let verified = try manager.verifyRestoration(testCase.path)
            #expect(verified)
            #expect(context.fileManager.fileExistsCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Snapshot Deletion Tests
    
    @Test("Test snapshot deletion", tags: ["snapshot", "delete"])
    func testSnapshotDeletion() throws {
        // Given: Snapshot manager
        let context = TestContext()
        let manager = context.createSnapshotManager()
        
        let snapshots = MockData.Snapshot.deletionData
        
        // Test snapshot deletion
        for snapshot in snapshots {
            // Delete snapshot
            try manager.deleteSnapshot(snapshot)
            #expect(context.resticService.deleteSnapshotCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify deletion
            do {
                _ = try manager.verifySnapshot(snapshot)
                throw TestFailure("Expected error for deleted snapshot")
            } catch {
                // Expected error
            }
            
            context.reset()
        }
    }
    
    // MARK: - Snapshot Comparison Tests
    
    @Test("Test snapshot comparison", tags: ["snapshot", "compare"])
    func testSnapshotComparison() throws {
        // Given: Snapshot manager
        let context = TestContext()
        let manager = context.createSnapshotManager()
        
        let comparisons = MockData.Snapshot.comparisonData
        
        // Test snapshot comparison
        for comparison in comparisons {
            // Compare snapshots
            let diff = try manager.compareSnapshots(comparison.first, comparison.second)
            #expect(diff != nil)
            #expect(context.resticService.compareSnapshotsCalled)
            
            // Verify differences
            let verified = try manager.verifyDifferences(diff!)
            #expect(verified)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test snapshot error handling", tags: ["snapshot", "error"])
    func testErrorHandling() throws {
        // Given: Snapshot manager
        let context = TestContext()
        let manager = context.createSnapshotManager()
        
        let errorCases = MockData.Snapshot.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                try manager.handleSnapshotOperation(errorCase)
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Expected error
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .backupSnapshotError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle snapshot edge cases", tags: ["snapshot", "edge"])
    func testEdgeCases() throws {
        // Given: Snapshot manager
        let context = TestContext()
        let manager = context.createSnapshotManager()
        
        // Test invalid snapshot ID
        do {
            try manager.verifySnapshot(BackupSnapshot(id: "invalid-id"))
            throw TestFailure("Expected error for invalid snapshot ID")
        } catch {
            // Expected error
        }
        
        // Test non-existent restore path
        do {
            try manager.restoreSnapshot(BackupSnapshot(id: "test"), to: "/non/existent/path")
            throw TestFailure("Expected error for non-existent path")
        } catch {
            // Expected error
        }
        
        // Test concurrent operations
        do {
            let snapshot = BackupSnapshot(id: "test")
            try manager.deleteSnapshot(snapshot)
            try manager.deleteSnapshot(snapshot)
            throw TestFailure("Expected error for concurrent deletion")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test snapshot performance", tags: ["snapshot", "performance"])
    func testPerformance() throws {
        // Given: Snapshot manager
        let context = TestContext()
        let manager = context.createSnapshotManager()
        
        // Test listing performance
        let startTime = context.dateProvider.now()
        let repository = MockData.Snapshot.validRepositories[0]
        
        for _ in 0..<100 {
            _ = try manager.listSnapshots(repository)
        }
        
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test filtering performance
        let snapshots = try manager.listSnapshots(repository)
        let filterStartTime = context.dateProvider.now()
        
        for _ in 0..<1000 {
            _ = try manager.filterSnapshots(snapshots, by: .latest)
        }
        
        let filterEndTime = context.dateProvider.now()
        
        let filterInterval = filterEndTime.timeIntervalSince(filterStartTime)
        #expect(filterInterval < 0.5) // Filtering should be fast
    }
}

// MARK: - Mock Restic Service

/// Mock implementation of ResticService for testing
final class MockResticService: ResticServiceProtocol {
    private(set) var createSnapshotCalled = false
    private(set) var verifySnapshotCalled = false
    private(set) var listSnapshotsCalled = false
    private(set) var restoreSnapshotCalled = false
    private(set) var deleteSnapshotCalled = false
    private(set) var compareSnapshotsCalled = false
    
    func createSnapshot(_ data: Data) throws -> BackupSnapshot {
        createSnapshotCalled = true
        return BackupSnapshot(id: "mock-snapshot")
    }
    
    func verifySnapshot(_ snapshot: BackupSnapshot) throws -> Bool {
        verifySnapshotCalled = true
        return true
    }
    
    func listSnapshots(_ repository: BackupRepository) throws -> [BackupSnapshot] {
        listSnapshotsCalled = true
        return [BackupSnapshot(id: "mock-snapshot")]
    }
    
    func restoreSnapshot(_ snapshot: BackupSnapshot, to path: String) throws {
        restoreSnapshotCalled = true
    }
    
    func deleteSnapshot(_ snapshot: BackupSnapshot) throws {
        deleteSnapshotCalled = true
    }
    
    func compareSnapshots(_ first: BackupSnapshot, _ second: BackupSnapshot) throws -> BackupSnapshotDiff {
        compareSnapshotsCalled = true
        return BackupSnapshotDiff(differences: ["mock-diff"])
    }
    
    func reset() {
        createSnapshotCalled = false
        verifySnapshotCalled = false
        listSnapshotsCalled = false
        restoreSnapshotCalled = false
        deleteSnapshotCalled = false
        compareSnapshotsCalled = false
    }
}
