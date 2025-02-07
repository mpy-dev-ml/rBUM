//
//  BackupServiceTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 03/02/2025.
//

@testable import Core
import XCTest

final class BackupServiceTests: XCTestCase {
    // MARK: - Properties
    
    private var backupService: TestBackupService!
    private var repository: Repository!
    private var configuration: BackupConfiguration!
    private var logger: TestLogger!
    private var notificationCenter: TestNotificationCenter!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        logger = TestLogger()
        notificationCenter = TestNotificationCenter()
        
        // Create test repository
        repository = Repository(
            id: UUID(),
            path: URL(fileURLWithPath: "/test/repo"),
            name: "Test Repository",
            description: "Test Description",
            credentials: RepositoryCredentials(password: "test-password")
        )
        
        // Create test backup configuration
        configuration = BackupConfiguration(
            id: UUID(),
            name: "Test Backup",
            sourcePaths: ["/test/source"],
            excludePatterns: ["*.tmp"],
            tags: ["test"],
            schedule: BackupSchedule(frequency: .daily, time: Date())
        )
        
        backupService = TestBackupService(
            logger: logger,
            notificationCenter: notificationCenter
        )
    }
    
    override func tearDown() async throws {
        backupService = nil
        repository = nil
        configuration = nil
        logger = nil
        notificationCenter = nil
        try await super.tearDown()
    }
    
    // MARK: - Tests
    
    func testStartBackup() async throws {
        // Test successful backup
        let result = try await backupService.startBackup(
            repository: repository,
            configuration: configuration
        )
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.repository.id, repository.id)
        XCTAssertEqual(result.configuration.id, configuration.id)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Starting backup") })
        XCTAssertTrue(logger.messages.contains { $0.contains("Backup completed") })
        
        // Verify notifications
        XCTAssertTrue(notificationCenter.postedNotifications.contains { $0.name == .backupStarted })
        XCTAssertTrue(notificationCenter.postedNotifications.contains { $0.name == .backupCompleted })
    }
    
    func testCancelBackup() async throws {
        // Start a backup
        let backupTask = Task {
            try await backupService.startBackup(
                repository: repository,
                configuration: configuration
            )
        }
        
        // Wait briefly to ensure backup has started
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Cancel the backup
        try await backupService.cancelBackup(
            repository: repository,
            configuration: configuration
        )
        
        let result = try await backupTask.value
        
        XCTAssertEqual(result.status, .cancelled)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Cancelling backup") })
        XCTAssertTrue(logger.messages.contains { $0.contains("Backup cancelled") })
        
        // Verify notifications
        XCTAssertTrue(notificationCenter.postedNotifications.contains { $0.name == .backupCancelled })
    }
    
    func testBackupProgress() async throws {
        let progressExpectation = XCTestExpectation(description: "Progress updates received")
        progressExpectation.expectedFulfillmentCount = 3 // Expect start, middle, and end updates
        
        let progressTask = Task {
            for try await progress in backupService.backupProgress(
                repository: repository,
                configuration: configuration
            ) {
                XCTAssertGreaterThanOrEqual(progress.percentComplete, 0)
                XCTAssertLessThanOrEqual(progress.percentComplete, 100)
                XCTAssertNotNil(progress.currentFile)
                XCTAssertGreaterThanOrEqual(progress.processedFiles, 0)
                XCTAssertGreaterThanOrEqual(progress.totalFiles, progress.processedFiles)
                progressExpectation.fulfill()
            }
        }
        
        // Start the backup
        let backupTask = Task {
            try await backupService.startBackup(
                repository: repository,
                configuration: configuration
            )
        }
        
        // Wait for progress updates
        await fulfillment(of: [progressExpectation], timeout: 5.0)
        
        // Ensure both tasks complete
        _ = try await backupTask.value
        await progressTask.value
    }
    
    func testBackupError() async throws {
        // Configure service to simulate an error
        backupService.shouldSimulateError = true
        
        do {
            _ = try await backupService.startBackup(
                repository: repository,
                configuration: configuration
            )
            XCTFail("Expected backup to throw an error")
        } catch {
            XCTAssertTrue(error is BackupError)
            if let backupError = error as? BackupError {
                XCTAssertEqual(backupError, .backupFailed)
            }
        }
        
        // Verify error logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Backup failed") })
        
        // Verify error notification
        XCTAssertTrue(notificationCenter.postedNotifications.contains { $0.name == .backupFailed })
    }
    
    func testConcurrentBackups() async throws {
        let concurrentBackups = 3
        let expectations = (0..<concurrentBackups).map { index in
            XCTestExpectation(description: "Backup \(index) completed")
        }
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentBackups {
                group.addTask {
                    do {
                        let result = try await self.backupService.startBackup(
                            repository: self.repository,
                            configuration: self.configuration
                        )
                        XCTAssertEqual(result.status, .completed)
                        expectations[i].fulfill()
                    } catch {
                        XCTFail("Backup \(i) failed: \(error)")
                    }
                }
            }
        }
        
        await fulfillment(of: expectations, timeout: 10.0)
    }
    
    func testBackupValidation() async throws {
        // Test invalid repository
        var invalidRepository = repository
        invalidRepository.path = URL(fileURLWithPath: "")
        
        do {
            _ = try await backupService.startBackup(
                repository: invalidRepository,
                configuration: configuration
            )
            XCTFail("Expected validation error for invalid repository")
        } catch {
            XCTAssertTrue(error is RepositoryError)
        }
        
        // Test invalid configuration
        var invalidConfiguration = configuration
        invalidConfiguration.sourcePaths = []
        
        do {
            _ = try await backupService.startBackup(
                repository: repository,
                configuration: invalidConfiguration
            )
            XCTFail("Expected validation error for invalid configuration")
        } catch {
            XCTAssertTrue(error is BackupError)
        }
    }
}

// MARK: - Test Helpers

private final class TestBackupService: BackupServiceProtocol {
    private let logger: LoggerProtocol
    private let notificationCenter: NotificationCenterProtocol
    var shouldSimulateError = false
    
    init(logger: LoggerProtocol, notificationCenter: NotificationCenterProtocol) {
        self.logger = logger
        self.notificationCenter = notificationCenter
    }
    
    func startBackup(repository: Repository, configuration: BackupConfiguration) async throws -> BackupResult {
        logger.info("Starting backup", privacy: .public)
        notificationCenter.post(name: .backupStarted, object: nil)
        
        if shouldSimulateError {
            logger.error("Backup failed", error: BackupError.backupFailed, privacy: .public)
            notificationCenter.post(name: .backupFailed, object: nil)
            throw BackupError.backupFailed
        }
        
        // Simulate backup work
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        logger.info("Backup completed", privacy: .public)
        notificationCenter.post(name: .backupCompleted, object: nil)
        
        return BackupResult(
            id: UUID(),
            repository: repository,
            configuration: configuration,
            startTime: Date(),
            endTime: Date(),
            status: .completed,
            filesProcessed: 100,
            bytesProcessed: 1024 * 1024
        )
    }
    
    func cancelBackup(repository: Repository, configuration: BackupConfiguration) async throws {
        logger.info("Cancelling backup", privacy: .public)
        notificationCenter.post(name: .backupCancelled, object: nil)
    }
    
    func backupProgress(repository: Repository, configuration: BackupConfiguration) -> AsyncStream<BackupProgress> {
        AsyncStream { continuation in
            Task {
                // Simulate progress updates
                for i in stride(from: 0, through: 100, by: 50) {
                    continuation.yield(BackupProgress(
                        percentComplete: Double(i),
                        currentFile: "/test/file\(i).txt",
                        processedFiles: i,
                        totalFiles: 100,
                        processedBytes: Int64(i * 1024 * 1024),
                        totalBytes: Int64(100 * 1024 * 1024)
                    ))
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                continuation.finish()
            }
        }
    }
}

private final class TestLogger: LoggerProtocol {
    var messages: [String] = []
    
    func log(
        level: LogLevel,
        message: String,
        metadata: [String: LogMetadataValue]?,
        privacy: LogPrivacy,
        error: Error?,
        file: String,
        function: String,
        line: Int
    ) {
        messages.append(message)
    }
}

private extension Notification.Name {
    static let backupStarted = Notification.Name("BackupStarted")
    static let backupCompleted = Notification.Name("BackupCompleted")
    static let backupCancelled = Notification.Name("BackupCancelled")
    static let backupFailed = Notification.Name("BackupFailed")
}
