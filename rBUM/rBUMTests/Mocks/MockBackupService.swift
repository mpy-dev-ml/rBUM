import Foundation
@testable import rBUM

/// Mock implementation of BackupService for testing
final class MockBackupService: BackupServiceProtocol {
    private var backups: [Backup] = []
    private var error: Error?
    
    /// Reset mock to initial state
    func reset() {
        backups = []
        error = nil
    }
    
    /// Set an error to be thrown by operations
    func setError(_ error: Error) {
        self.error = error
    }
    
    // MARK: - Protocol Implementation
    
    func createBackup(
        paths: [URL],
        to repository: Repository,
        credentials: RepositoryCredentials,
        tags: [String]?,
        onProgress: ((BackupProgress) -> Void)?,
        onStatusChange: ((BackupStatus) -> Void)?
    ) async throws {
        if let error = error { throw error }
        
        // Simulate backup progress
        onStatusChange?(.preparing)
        onProgress?(BackupProgress(totalFiles: 100, processedFiles: 0, totalBytes: 1024 * 1024, processedBytes: 0))
        
        // Simulate backup completion
        onStatusChange?(.completed)
        onProgress?(BackupProgress(totalFiles: 100, processedFiles: 100, totalBytes: 1024 * 1024, processedBytes: 1024 * 1024))
    }
}
