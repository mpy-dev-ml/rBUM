import Foundation
@testable import rBUM

/// Test utilities for common test operations
enum TestUtilities {
    /// Create a temporary directory for test files
    static func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        return tempDir
    }
    
    /// Create a temporary file with content
    static func createTempFile(content: String) throws -> URL {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try content.write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile
    }
    
    /// Remove temporary test files
    static func cleanupTempFiles(_ urls: [URL]) {
        urls.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    /// Create a test repository with mock data
    static func createTestRepository() -> Repository {
        MockData.Repository.validRepository
    }
    
    /// Create test credentials
    static func createTestCredentials() -> RepositoryCredentials {
        MockData.Credentials.validCredentials
    }
    
    /// Create test snapshots
    static func createTestSnapshots(count: Int = 3) -> [Snapshot] {
        (0..<count).map { i in
            Snapshot(
                id: "snap\(i)",
                time: Date().addingTimeInterval(Double(-i * 86400)),
                paths: ["/test/path\(i)"],
                hostname: "host\(i)",
                username: "user\(i)",
                tags: ["test\(i)"]
            )
        }
    }
    
    /// Create test backup progress
    static func createTestBackupProgress(
        percentage: Int = 50,
        filesProcessed: Int = 10
    ) -> BackupProgress {
        BackupProgress(
            bytesProcessed: Int64(percentage) * 1024,
            totalBytes: 102400,
            filesProcessed: filesProcessed,
            totalFiles: 20,
            currentFile: "/test/current.txt",
            percentage: percentage
        )
    }
}
