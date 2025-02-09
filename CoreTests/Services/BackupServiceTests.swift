//
//  BackupServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 09/02/2025.
//

@testable import Core
import Foundation
import Testing

struct BackupServiceTests {
    // MARK: - Test Properties
    
    let mockService = MockBackupService()
    let mockDelegate = MockBackupServiceDelegate()
    let testRepository = Repository(
        id: "test-repo",
        name: "Test Repository",
        url: URL(string: "restic://test")!,
        credentials: .init(password: "test-password")
    )
    
    // MARK: - Setup
    
    func setUp() {
        mockService.delegate = mockDelegate
        mockService.shouldFail = false
        mockService.simulatedDelay = 0
        mockService.simulatedProgress = nil
    }
    
    // MARK: - Tests
    
    @Test
    func testInitializeRepository() async throws {
        let options = RepositoryOptions(encryption: .aes256)
        try await mockService.initializeRepository(testRepository, options: options)
        #expect(mockDelegate.statusChanges.contains(.preparing))
    }
    
    @Test
    func testCreateBackup() async throws {
        let paths = ["/test/path"]
        let tags = ["test"]
        let options = BackupOptions(incremental: true)
        
        let snapshot = try await mockService.createBackup(
            to: testRepository,
            paths: paths,
            tags: tags,
            options: options
        )
        
        #expect(snapshot.paths == paths)
        #expect(snapshot.tags == tags)
        #expect(snapshot.repositoryId == testRepository.id)
    }
    
    @Test
    func testListSnapshots() async throws {
        let filter = SnapshotFilter(tags: ["test"])
        let snapshots = try await mockService.listSnapshots(
            in: testRepository,
            filter: filter
        )
        
        #expect(!snapshots.isEmpty)
        #expect(snapshots[0].repositoryId == testRepository.id)
    }
    
    @Test
    func testRestore() async throws {
        let snapshot = ResticSnapshot(
            id: "test-snapshot",
            time: Date(),
            hostname: "test-host",
            tags: ["test"],
            paths: ["/test"],
            parent: nil,
            size: 1024,
            repositoryId: testRepository.id
        )
        
        let options = RestoreOptions(verify: true)
        try await mockService.restore(
            snapshot: snapshot,
            from: testRepository,
            paths: ["/test"],
            to: "/restore",
            options: options
        )
        
        #expect(mockDelegate.statusChanges.contains(.completed))
    }
    
    @Test
    func testCheckRepository() async throws {
        let options = CheckOptions(readData: true)
        let result = try await mockService.checkRepository(
            testRepository,
            options: options
        )
        
        #expect(result.success)
        #expect(result.errors.isEmpty)
    }
    
    @Test
    func testPruneSnapshots() async throws {
        let policy = RetentionPolicy(
            keepLast: 5,
            keepDaily: 7,
            keepWeekly: 4
        )
        
        let result = try await mockService.pruneSnapshots(
            in: testRepository,
            policy: policy
        )
        
        #expect(result.snapshotsRemoved > 0)
        #expect(result.bytesReclaimed > 0)
    }
    
    @Test
    func testOperationFailure() async {
        mockService.shouldFail = true
        
        #expect(throws: BackupError.self) {
            try await mockService.initializeRepository(testRepository, options: nil)
        }
    }
    
    @Test
    func testProgressUpdates() async throws {
        let progress = BackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1024 * 1024,
            processedBytes: 512 * 1024,
            currentFile: "/test/file",
            estimatedTimeRemaining: 60
        )
        
        mockService.simulatedProgress = progress
        
        try await mockService.createBackup(
            to: testRepository,
            paths: ["/test"],
            tags: nil,
            options: nil
        )
        
        #expect(mockDelegate.lastProgress?.processedFiles == 50)
        #expect(mockDelegate.lastProgress?.totalFiles == 100)
    }
    
    @Test
    func testPauseResume() async throws {
        let progress = BackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1024 * 1024,
            processedBytes: 512 * 1024
        )
        
        mockService.simulatedProgress = progress
        mockService.simulatedDelay = 1
        
        // Start a long-running operation
        Task {
            try await mockService.createBackup(
                to: testRepository,
                paths: ["/test"],
                tags: nil,
                options: nil
            )
        }
        
        // Give time for the operation to start
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Test pause
        await mockService.pauseCurrentOperation()
        #expect(mockDelegate.statusChanges.contains(.paused(progress)))
        
        // Test resume
        await mockService.resumeCurrentOperation()
        #expect(mockDelegate.statusChanges.contains(.running(progress)))
    }
    
    @Test
    func testCancel() async throws {
        mockService.simulatedDelay = 1
        
        // Start a long-running operation
        Task {
            try await mockService.createBackup(
                to: testRepository,
                paths: ["/test"],
                tags: nil,
                options: nil
            )
        }
        
        // Give time for the operation to start
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Test cancel
        await mockService.cancelCurrentOperation()
        #expect(mockDelegate.statusChanges.contains(.completed))
    }
}

// MARK: - Mock Delegate

final class MockBackupServiceDelegate: BackupServiceDelegate {
    private(set) var statusChanges: [BackupStatus] = []
    private(set) var lastProgress: BackupProgress?
    private(set) var lastPrompt: String?
    private(set) var shouldProvideInput = true
    
    func backupService(
        _ service: BackupServiceProtocol,
        didUpdateProgress progress: BackupProgress
    ) {
        lastProgress = progress
    }
    
    func backupService(
        _ service: BackupServiceProtocol,
        didChangeStatus status: BackupStatus
    ) {
        statusChanges.append(status)
    }
    
    func backupService(
        _ service: BackupServiceProtocol,
        requiresInput prompt: String
    ) async -> String? {
        lastPrompt = prompt
        return shouldProvideInput ? "test-input" : nil
    }
}
