//
//  BackupIntegrationTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 03/02/2025.
//

import XCTest
@testable import rBUM
@testable import Core

final class BackupIntegrationTests: XCTestCase {
    // MARK: - Properties
    
    private var backupService: BackupService!
    private var repositoryService: RepositoryService!
    private var securityService: SecurityService!
    private var bookmarkService: BookmarkService!
    private var keychainService: KeychainService!
    private var logger: TestLogger!
    
    private var testDirectory: URL!
    private var backupDirectory: URL!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test directories
        let fileManager = FileManager.default
        testDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        backupDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        
        // Create test files
        try "Test content 1".write(to: testDirectory.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "Test content 2".write(to: testDirectory.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
        
        // Create subdirectory with files
        let subDirectory = testDirectory.appendingPathComponent("subdir")
        try fileManager.createDirectory(at: subDirectory, withIntermediateDirectories: true)
        try "Test content 3".write(to: subDirectory.appendingPathComponent("file3.txt"), atomically: true, encoding: .utf8)
        
        // Initialize services
        logger = TestLogger()
        
        keychainService = KeychainService(
            serviceName: "dev.mpy.rBUM.test",
            accessGroup: "dev.mpy.rBUM.test.shared",
            logger: logger
        )
        
        bookmarkService = BookmarkService(
            persistenceService: BookmarkPersistenceService(logger: logger),
            fileManager: FileManager.default,
            logger: logger
        )
        
        securityService = SecurityService(
            keychainService: keychainService,
            bookmarkService: bookmarkService,
            logger: logger
        )
        
        repositoryService = RepositoryService(
            securityService: securityService,
            logger: logger
        )
        
        backupService = BackupService(
            repositoryService: repositoryService,
            securityService: securityService,
            logger: logger
        )
    }
    
    override func tearDown() async throws {
        // Clean up test directories
        try FileManager.default.removeItem(at: testDirectory)
        try FileManager.default.removeItem(at: backupDirectory)
        
        backupService = nil
        repositoryService = nil
        securityService = nil
        bookmarkService = nil
        keychainService = nil
        logger = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestRepository() throws -> Repository {
        let credentials = RepositoryCredentials(password: "test-password")
        let repository = Repository(
            id: UUID(),
            name: "Test Repository",
            description: "Test Description",
            path: backupDirectory.path,
            created: Date(),
            lastAccessed: Date()
        )
        
        try securityService.saveCredentials(credentials, for: repository.id)
        try repositoryService.saveRepository(repository)
        
        return repository
    }
    
    // MARK: - Tests
    
    func testCompleteBackupFlow() async throws {
        // Create repository
        let repository = try createTestRepository()
        
        // Create backup configuration
        let backupConfig = BackupConfiguration(
            id: UUID(),
            name: "Test Backup",
            repositoryId: repository.id,
            sourcePaths: [testDirectory.path],
            excludePatterns: ["*.tmp"],
            tags: ["test"],
            schedule: nil,
            created: Date(),
            lastRun: nil
        )
        
        // Perform backup
        let progress = Progress()
        let result = try await backupService.performBackup(
            config: backupConfig,
            progress: progress
        )
        
        // Verify backup success
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertNotNil(result.snapshotId)
        
        // Verify files were backed up
        let snapshots = try await backupService.listSnapshots(for: repository.id)
        XCTAssertEqual(snapshots.count, 1)
        
        let snapshot = snapshots[0]
        XCTAssertEqual(snapshot.fileCount, 3)
        XCTAssertGreaterThan(snapshot.size, 0)
        
        // Verify snapshot contents
        let files = try await backupService.listFiles(
            snapshot: snapshot.id,
            repository: repository.id
        )
        
        XCTAssertEqual(files.count, 3)
        XCTAssertTrue(files.contains { $0.path.hasSuffix("file1.txt") })
        XCTAssertTrue(files.contains { $0.path.hasSuffix("file2.txt") })
        XCTAssertTrue(files.contains { $0.path.hasSuffix("file3.txt") })
        
        // Test file restoration
        let restoreDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
        
        let restoreProgress = Progress()
        try await backupService.restoreFiles(
            from: snapshot.id,
            repository: repository.id,
            to: restoreDirectory.path,
            progress: restoreProgress
        )
        
        // Verify restored files
        let restoredFiles = try FileManager.default.contentsOfDirectory(
            at: restoreDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(restoredFiles.count, 3)
        
        // Clean up restore directory
        try FileManager.default.removeItem(at: restoreDirectory)
    }
    
    func testBackupWithEncryption() async throws {
        // Create repository with encryption
        let repository = try createTestRepository()
        
        // Create backup configuration
        let backupConfig = BackupConfiguration(
            id: UUID(),
            name: "Encrypted Backup",
            repositoryId: repository.id,
            sourcePaths: [testDirectory.path],
            excludePatterns: [],
            tags: ["encrypted"],
            schedule: nil,
            created: Date(),
            lastRun: nil
        )
        
        // Perform backup
        let progress = Progress()
        let result = try await backupService.performBackup(
            config: backupConfig,
            progress: progress
        )
        
        XCTAssertTrue(result.success)
        
        // Verify encryption
        let snapshotPath = backupDirectory.appendingPathComponent("snapshots")
            .appendingPathComponent(result.snapshotId!.uuidString)
        
        // Read raw backup data
        let backupData = try Data(contentsOf: snapshotPath)
        
        // Verify data is encrypted (not plaintext)
        let originalContent = "Test content 1"
        XCTAssertFalse(String(data: backupData, encoding: .utf8)?.contains(originalContent) ?? false)
    }
    
    func testConcurrentBackups() async throws {
        // Create repository
        let repository = try createTestRepository()
        
        // Create multiple backup configurations
        let configs = (0..<5).map { i in
            BackupConfiguration(
                id: UUID(),
                name: "Backup \(i)",
                repositoryId: repository.id,
                sourcePaths: [testDirectory.path],
                excludePatterns: [],
                tags: ["concurrent"],
                schedule: nil,
                created: Date(),
                lastRun: nil
            )
        }
        
        // Perform backups concurrently
        try await withThrowingTaskGroup(of: BackupResult.self) { group in
            for config in configs {
                group.addTask {
                    let progress = Progress()
                    return try await self.backupService.performBackup(
                        config: config,
                        progress: progress
                    )
                }
            }
            
            // Verify all backups succeeded
            var results: [BackupResult] = []
            for try await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, configs.count)
            XCTAssertTrue(results.allSatisfy { $0.success })
        }
        
        // Verify snapshots
        let snapshots = try await backupService.listSnapshots(for: repository.id)
        XCTAssertEqual(snapshots.count, configs.count)
    }
    
    func testBackupRecovery() async throws {
        // Create repository
        let repository = try createTestRepository()
        
        // Create backup configuration
        let backupConfig = BackupConfiguration(
            id: UUID(),
            name: "Recovery Test",
            repositoryId: repository.id,
            sourcePaths: [testDirectory.path],
            excludePatterns: [],
            tags: ["recovery"],
            schedule: nil,
            created: Date(),
            lastRun: nil
        )
        
        // Perform initial backup
        let progress = Progress()
        let result = try await backupService.performBackup(
            config: backupConfig,
            progress: progress
        )
        
        XCTAssertTrue(result.success)
        
        // Delete original files
        try FileManager.default.removeItem(at: testDirectory)
        
        // Restore from backup
        let restoreDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
        
        let restoreProgress = Progress()
        try await backupService.restoreFiles(
            from: result.snapshotId!,
            repository: repository.id,
            to: restoreDirectory.path,
            progress: restoreProgress
        )
        
        // Verify restored files
        let restoredFiles = try FileManager.default.contentsOfDirectory(
            at: restoreDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        XCTAssertEqual(restoredFiles.count, 2) // file1.txt, file2.txt in root
        
        let subdir = restoreDirectory.appendingPathComponent("subdir")
        let subdirFiles = try FileManager.default.contentsOfDirectory(
            at: subdir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        XCTAssertEqual(subdirFiles.count, 1) // file3.txt in subdir
        
        // Verify file contents
        let file1Content = try String(contentsOf: restoreDirectory.appendingPathComponent("file1.txt"))
        XCTAssertEqual(file1Content, "Test content 1")
        
        let file2Content = try String(contentsOf: restoreDirectory.appendingPathComponent("file2.txt"))
        XCTAssertEqual(file2Content, "Test content 2")
        
        let file3Content = try String(contentsOf: subdir.appendingPathComponent("file3.txt"))
        XCTAssertEqual(file3Content, "Test content 3")
        
        // Clean up restore directory
        try FileManager.default.removeItem(at: restoreDirectory)
    }
}
