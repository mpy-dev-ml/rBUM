/// Mock implementation of ResticCommandService for testing
final class MockResticCommandService: ResticCommandServiceProtocol {
    // MARK: - Control Properties
    
    var error: Error?                     // Simulated error
    var initializeDelay: TimeInterval = 0 // Simulated operation delay
    var backupProgress: BackupProgress?   // Simulated backup progress
    var snapshots: [Snapshot] = []        // Simulated snapshots
    
    // MARK: - Call Tracking
    
    var initializeCalled = false
    var backupCalled = false
    var listSnapshotsCalled = false
    var pruneCalled = false
    
    // MARK: - Last Parameters
    
    var lastInitPath: URL?
    var lastInitPassword: String?
    var lastBackupPaths: [URL]?
    var lastBackupRepository: Repository?
    var lastBackupCredentials: RepositoryCredentials?
    
    // MARK: - ResticCommandServiceProtocol Implementation
    
    func initializeRepository(at path: URL, password: String) async throws {
        if let error = error { throw error }
        try await Task.sleep(nanoseconds: UInt64(initializeDelay * 1_000_000_000))
        
        initializeCalled = true
        lastInitPath = path
        lastInitPassword = password
    }
    
    func createBackup(
        paths: [URL],
        to repository: Repository,
        credentials: RepositoryCredentials,
        tags: [String]?,
        onProgress: ((BackupProgress) -> Void)?,
        onStatusChange: ((BackupStatus) -> Void)?
    ) async throws {
        if let error = error { throw error }
        
        backupCalled = true
        lastBackupPaths = paths
        lastBackupRepository = repository
        lastBackupCredentials = credentials
        
        if let progress = backupProgress {
            onProgress?(progress)
        }
    }
    
    func listSnapshots(
        in repository: Repository,
        credentials: RepositoryCredentials
    ) async throws -> [Snapshot] {
        if let error = error { throw error }
        
        listSnapshotsCalled = true
        return snapshots
    }
    
    func pruneSnapshots(
        in repository: Repository,
        credentials: RepositoryCredentials,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {
        if let error = error { throw error }
        pruneCalled = true
    }
    
    // MARK: - Reset
    
    func reset() {
        error = nil
        initializeDelay = 0
        backupProgress = nil
        snapshots = []
        
        initializeCalled = false
        backupCalled = false
        listSnapshotsCalled = false
        pruneCalled = false
        
        lastInitPath = nil
        lastInitPassword = nil
        lastBackupPaths = nil
        lastBackupRepository = nil
        lastBackupCredentials = nil
    }
}
