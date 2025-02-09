@testable import Core
@testable import rBUM
import Testing

struct FileBasedRepositoryLockTests {
    struct TestRepository {
        static let path = "/tmp/test_repo"
        static let repository = Repository(
            path: path,
            settings: .init(),
            options: nil,
            credentials: .init(password: "test")
        )
    }
    
    @Test("acquireLock should succeed when repository is not locked")
    func testAcquireLockSuccess() async throws {
        // Arrange
        let mockLogger = MockLogger()
        let lock = FileBasedRepositoryLock(logger: mockLogger)
        
        // Act
        let acquired = try await lock.acquireLock(
            for: TestRepository.repository,
            operation: .backup,
            timeout: 5
        )
        
        // Assert
        #expect(acquired)
        let status = try await lock.checkLockStatus(for: TestRepository.repository)
        #expect(status != nil)
        #expect(status?.operation == .backup)
        
        // Cleanup
        try await lock.releaseLock(for: TestRepository.repository, operation: .backup)
    }
    
    @Test("acquireLock should fail when repository is already locked")
    func testAcquireLockFailureWhenLocked() async throws {
        // Arrange
        let mockLogger = MockLogger()
        let lock = FileBasedRepositoryLock(logger: mockLogger)
        
        // First lock
        let acquired = try await lock.acquireLock(
            for: TestRepository.repository,
            operation: .backup,
            timeout: 5
        )
        #expect(acquired)
        
        // Act & Assert
        do {
            _ = try await lock.acquireLock(
                for: TestRepository.repository,
                operation: .restore,
                timeout: 1
            )
            #expect(false, "Should have thrown alreadyLocked error")
        } catch let error as LockError {
            switch error {
            case .alreadyLocked(let info):
                #expect(info.operation == .backup)
            default:
                #expect(false, "Wrong error type: \(error)")
            }
        }
        
        // Cleanup
        try await lock.releaseLock(for: TestRepository.repository, operation: .backup)
    }
    
    @Test("releaseLock should succeed when lock is owned by current process")
    func testReleaseLockSuccess() async throws {
        // Arrange
        let mockLogger = MockLogger()
        let lock = FileBasedRepositoryLock(logger: mockLogger)
        
        // Setup
        let acquired = try await lock.acquireLock(
            for: TestRepository.repository,
            operation: .backup,
            timeout: 5
        )
        #expect(acquired)
        
        // Act
        try await lock.releaseLock(for: TestRepository.repository, operation: .backup)
        
        // Assert
        let status = try await lock.checkLockStatus(for: TestRepository.repository)
        #expect(status == nil)
    }
    
    @Test("breakStaleLock should succeed when lock is stale")
    func testBreakStaleLock() async throws {
        // Arrange
        let mockLogger = MockLogger()
        let lock = FileBasedRepositoryLock(logger: mockLogger)
        
        // Create a stale lock by manipulating the timestamp
        let staleLock = LockInfo(
            operation: .backup,
            timestamp: Date().addingTimeInterval(-7200), // 2 hours old
            pid: -1, // Invalid PID
            hostname: "test",
            username: "test"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let lockData = try encoder.encode(staleLock)
        try lockData.write(
            to: URL(fileURLWithPath: TestRepository.path).appendingPathComponent(".lock"),
            options: .atomic
        )
        
        // Act
        try await lock.breakStaleLock(for: TestRepository.repository)
        
        // Assert
        let status = try await lock.checkLockStatus(for: TestRepository.repository)
        #expect(status == nil)
    }
    
    @Test("checkLockStatus should return correct lock info")
    func testCheckLockStatus() async throws {
        // Arrange
        let mockLogger = MockLogger()
        let lock = FileBasedRepositoryLock(logger: mockLogger)
        
        // Act
        let acquired = try await lock.acquireLock(
            for: TestRepository.repository,
            operation: .backup,
            timeout: 5
        )
        #expect(acquired)
        
        // Assert
        let status = try await lock.checkLockStatus(for: TestRepository.repository)
        #expect(status != nil)
        #expect(status?.operation == .backup)
        #expect(status?.pid == ProcessInfo.processInfo.processIdentifier)
        
        // Cleanup
        try await lock.releaseLock(for: TestRepository.repository, operation: .backup)
    }
}

private final class MockLogger: LoggerProtocol {
    func debug(_ message: String) {}
    func info(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}
}
