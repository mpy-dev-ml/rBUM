//
//  MockBackupService.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 09/02/2025.
//

@testable import Core
import Foundation

final class MockBackupService: BackupServiceProtocol {
    weak var delegate: BackupServiceDelegate?
    private(set) var currentStatus: BackupStatus = .preparing
    
    // MARK: - Mock Control
    
    var shouldFail = false
    var simulatedDelay: TimeInterval = 0
    var simulatedProgress: BackupProgress?
    
    private func simulateOperation() async throws {
        if shouldFail {
            throw BackupError.operationFailed("Simulated failure")
        }
        
        if let progress = simulatedProgress {
            delegate?.backupService(self, didUpdateProgress: progress)
        }
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
    }
    
    // MARK: - BackupServiceProtocol
    
    func initializeRepository(_ repository: Repository, options: RepositoryOptions?) async throws {
        try await simulateOperation()
    }
    
    func createBackup(
        to repository: Repository,
        paths: [String],
        tags: [String]?,
        options: BackupOptions?
    ) async throws -> ResticSnapshot {
        try await simulateOperation()
        
        return ResticSnapshot(
            id: "mock-snapshot-id",
            time: Date(),
            hostname: "mock-host",
            tags: tags,
            paths: paths,
            parent: nil,
            size: 1024,
            repositoryId: repository.id
        )
    }
    
    func listSnapshots(
        in repository: Repository,
        filter: SnapshotFilter?
    ) async throws -> [ResticSnapshot] {
        try await simulateOperation()
        
        return [
            ResticSnapshot(
                id: "mock-snapshot-1",
                time: Date(),
                hostname: "mock-host",
                tags: ["test"],
                paths: ["/test"],
                parent: nil,
                size: 1024,
                repositoryId: repository.id
            )
        ]
    }
    
    func restore(
        snapshot: ResticSnapshot,
        from repository: Repository,
        paths: [String]?,
        to target: String,
        options: RestoreOptions?
    ) async throws {
        try await simulateOperation()
    }
    
    func checkRepository(
        _ repository: Repository,
        options: CheckOptions?
    ) async throws -> RepositoryCheckResult {
        try await simulateOperation()
        
        return RepositoryCheckResult(
            success: true,
            blobsChecked: 100,
            bytesChecked: 1024 * 1024,
            errors: []
        )
    }
    
    func pruneSnapshots(
        in repository: Repository,
        policy: RetentionPolicy
    ) async throws -> PruningResult {
        try await simulateOperation()
        
        return PruningResult(
            snapshotsRemoved: 5,
            blobsRemoved: 50,
            bytesReclaimed: 1024 * 1024
        )
    }
    
    func cancelCurrentOperation() async {
        currentStatus = .completed
        delegate?.backupService(self, didChangeStatus: currentStatus)
    }
    
    func pauseCurrentOperation() async {
        if case .running(let progress) = currentStatus {
            currentStatus = .paused(progress)
            delegate?.backupService(self, didChangeStatus: currentStatus)
        }
    }
    
    func resumeCurrentOperation() async {
        if case .paused(let progress) = currentStatus {
            currentStatus = .running(progress)
            delegate?.backupService(self, didChangeStatus: currentStatus)
        }
    }
}

enum BackupError: Error {
    case operationFailed(String)
}
