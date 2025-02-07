//
//  BackupServiceTests.swift
//  rBUM
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

        try setupTestEnvironment()
    }

    private func setupTestEnvironment() throws {
        try setupTestRepository()
        try setupTestConfiguration()
        setupMockServices()
    }

    private func setupTestRepository() throws {
        // Create test repository
        repository = Repository(
            id: UUID(),
            path: URL(fileURLWithPath: "/test/repo"),
            name: "Test Repository",
            description: "Test Description",
            credentials: RepositoryCredentials(password: "test-password")
        )
    }

    private func setupTestConfiguration() throws {
        // Create test backup configuration
        configuration = BackupConfiguration(
            id: UUID(),
            name: "Test Backup",
            sourcePaths: ["/test/source"],
            excludePatterns: ["*.tmp"],
            tags: ["test"],
            schedule: BackupSchedule(frequency: .daily, time: Date())
        )
    }

    private func setupMockServices() {
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

    // MARK: - Test Setup

    // MARK: - Backup Tests

    func testStartBackup() async throws {
        // Test successful backup
        let result = try await backupService.startBackup(
            repository: repository,
            configuration: configuration
        )

        verifyBackupResult(result)

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
                verifyBackupProgress(progress)
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
        let numberOfConcurrentBackups = 3
        let expectations = (0 ..< numberOfConcurrentBackups).map { backupIndex in
            XCTestExpectation(description: "Backup \(backupIndex) completed")
        }

        await withTaskGroup(of: Void.self) { group in
            for backupIndex in 0 ..< numberOfConcurrentBackups {
                group.addTask {
                    do {
                        let result = try await self.backupService.startBackup(
                            repository: self.repository,
                            configuration: self.configuration
                        )
                        self.verifyBackupResult(result)
                        expectations[backupIndex].fulfill()
                    } catch {
                        XCTFail("Backup \(backupIndex) failed: \(error)")
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

    // MARK: - Test Helpers

    private func verifyBackupResult(_ result: BackupResult) {
        XCTAssertEqual(result.status, .completed)
        XCTAssertNil(result.error)
        XCTAssertGreaterThan(result.duration, 0)
        XCTAssertLessThan(result.duration, 5.0) // Should complete within 5 seconds
    }

    private func verifyBackupProgress(_ progress: BackupProgress) {
        XCTAssertGreaterThanOrEqual(progress.percentComplete, 0)
        XCTAssertLessThanOrEqual(progress.percentComplete, 100)
        XCTAssertNotNil(progress.currentFile)
        XCTAssertGreaterThanOrEqual(progress.processedFiles, 0)
        XCTAssertGreaterThanOrEqual(progress.totalFiles, progress.processedFiles)
        XCTAssertGreaterThanOrEqual(progress.processedBytes, 0)
        XCTAssertGreaterThanOrEqual(progress.totalBytes, progress.processedBytes)
    }

    private func createBackupConfiguration(
        source: URL,
        destination: URL,
        excludes: [String] = [],
        tags: [String] = []
    ) -> BackupConfiguration {
        BackupConfiguration(
            id: UUID(),
            name: "Test Backup",
            sourcePaths: [source.path],
            excludePatterns: excludes,
            tags: tags,
            schedule: BackupSchedule(frequency: .daily, time: Date())
        )
    }

    private func validateBackupResults(
        source: URL,
        destination: URL,
        fileCount: Int,
        expectedSize: Int64
    ) async throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        )

        XCTAssertEqual(files.count, fileCount, "Incorrect number of files backed up")

        let totalSize = try files.reduce(0) { sum, file in
            let attributes = try file.resourceValues(forKeys: [.fileSizeKey])
            return sum + Int64(attributes.fileSize ?? 0)
        }

        XCTAssertEqual(totalSize, expectedSize, "Incorrect total size of backed up files")
    }
}

// MARK: - Test Helpers

private final class TestLogger: LoggerProtocol {
    var messages: [String] = []
    
    func log(
        level: LogLevel = .info,
        message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        let errorText = error.map { " Error: \($0)" } ?? ""
        let metadataText = metadata.map { " Metadata: \($0)" } ?? ""
        messages.append("[\(level)] \(message)\(errorText)\(metadataText)")
    }
}

private final class TestBackupService: BackupServiceProtocol {
    private let logger: LoggerProtocol
    private let notificationCenter: NotificationCenterProtocol
    var shouldSimulateError = false

    init(logger: LoggerProtocol, notificationCenter: NotificationCenterProtocol) {
        self.logger = logger
        self.notificationCenter = notificationCenter
    }

    private struct LogContext {
        let message: String
        let level: LogLevel
        let error: Error?
        
        static func info(_ message: String) -> LogContext {
            LogContext(message: message, level: .info, error: nil)
        }
        
        static func error(_ message: String, error: Error) -> LogContext {
            LogContext(message: message, level: .error, error: error)
        }
    }
    
    private func log(_ context: LogContext) {
        logger.log(
            level: context.level,
            message: context.message,
            metadata: nil,
            privacy: .public,
            error: context.error,
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    func startBackup(
        repository: Repository,
        configuration: BackupConfiguration
    ) async throws -> BackupResult {
        log(.info("Starting backup"))
        notificationCenter.post(name: .backupStarted, object: nil)

        if shouldSimulateError {
            log(.error("Backup failed", error: BackupError.backupFailed))
            notificationCenter.post(name: .backupFailed, object: nil)
            throw BackupError.backupFailed
        }

        // Simulate backup work
        try await Task.sleep(nanoseconds: 1_000_000_000)

        log(.info("Backup completed"))
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

    func cancelBackup(
        repository _: Repository,
        configuration _: BackupConfiguration
    ) async throws {
        log(.info("Cancelling backup"))
        notificationCenter.post(name: .backupCancelled, object: nil)
    }

    func backupProgress(
        repository _: Repository,
        configuration _: BackupConfiguration
    ) -> AsyncStream<BackupProgress> {
        AsyncStream { continuation in
            Task {
                // Simulate progress updates
                for progressIndex in stride(from: 0, through: 100, by: 50) {
                    continuation.yield(
                        BackupProgress(
                            percentComplete: Double(progressIndex),
                            currentFile: "/test/file\(progressIndex).txt",
                            processedFiles: progressIndex,
                            totalFiles: 100,
                            processedBytes: Int64(progressIndex * 1024 * 1024),
                            totalBytes: Int64(100 * 1024 * 1024)
                        )
                    )
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                continuation.finish()
            }
        }
    }
}

private final class TestNotificationCenter: NotificationCenterProtocol {
    var postedNotifications: [Notification] = []

    func post(name: Notification.Name, object: Any?) {
        postedNotifications.append(Notification(name: name, object: object))
    }
}

private extension Notification.Name {
    static let backupStarted = Notification.Name("BackupStarted")
    static let backupCompleted = Notification.Name("BackupCompleted")
    static let backupCancelled = Notification.Name("BackupCancelled")
    static let backupFailed = Notification.Name("BackupFailed")
}
