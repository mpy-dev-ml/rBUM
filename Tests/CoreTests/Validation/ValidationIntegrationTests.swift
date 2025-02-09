@testable import Core
import Testing

/// Integration tests for validation components
///
/// These tests verify that different validation components work together correctly,
/// testing real-world scenarios that involve multiple validation steps.
struct ValidationIntegrationTests {
    let mockLogger = MockLogger()
    let mockXPCService = MockXPCService()
    let mockFileManager = MockFileManager()
    let mockSecurityService = MockSecurityService()
    
    var sut: ResticCommandService {
        ResticCommandService(
            xpcService: mockXPCService,
            logger: mockLogger,
            fileManager: mockFileManager,
            securityService: mockSecurityService
        )
    }
    
    @Test("Full backup validation succeeds with valid inputs")
    func testFullBackupValidationValid() async throws {
        // Arrange
        let repository = Repository.mock()
        let paths = ["/valid/backup/path"]
        let excludePatterns = ["*.tmp", "cache/*"]
        let tags = ["daily", "automated"]
        
        mockFileManager.fileExistsHandler = { _ in true }
        mockFileManager.isReadableHandler = { _ in true }
        mockSecurityService.hasAccessHandler = { _ in true }
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 0, output: "")
        }
        
        // Act & Assert
        #expect(try await sut.validateBackupOperation(
            repository: repository,
            paths: paths,
            excludePatterns: excludePatterns,
            tags: tags
        ) == nil)
    }
    
    @Test("Full restore validation succeeds with valid inputs")
    func testFullRestoreValidationValid() async throws {
        // Arrange
        let repository = Repository.mock()
        let snapshot = ResticSnapshot.mock()
        let targetPath = "/valid/restore/path"
        let includePatterns = ["docs/*", "*.pdf"]
        
        mockFileManager.fileExistsHandler = { _ in true }
        mockFileManager.isReadableHandler = { _ in true }
        mockSecurityService.hasAccessHandler = { _ in true }
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 0, output: """
                [{
                    "id": "\(snapshot.id)",
                    "time": "2025-02-09T09:21:17Z",
                    "paths": ["/test"],
                    "tags": ["test"]
                }]
                """)
        }
        
        // Act & Assert
        #expect(try await sut.validateRestoreOperation(
            repository: repository,
            snapshot: snapshot,
            targetPath: targetPath,
            includePatterns: includePatterns
        ) == nil)
    }
    
    @Test("Repository initialisation validation with key file")
    func testRepositoryInitValidationWithKeyFile() async throws {
        // Arrange
        var repository = Repository.mock()
        repository.credentials.keyFile = "/valid/key/file"
        
        mockFileManager.fileExistsHandler = { path in
            path.contains("key/file")
        }
        mockFileManager.isReadableHandler = { _ in true }
        mockFileManager.attributesHandler = { _ in
            [.size: 1024] as [FileAttributeKey: Any]
        }
        mockSecurityService.hasAccessHandler = { _ in true }
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 0, output: "")
        }
        
        // Act & Assert
        #expect(try await sut.validateRepositoryInit(repository) == nil)
    }
    
    @Test("Snapshot management validation with tags and paths")
    func testSnapshotManagementValidation() async throws {
        // Arrange
        let repository = Repository.mock()
        let snapshot = ResticSnapshot.mock()
        let paths = ["/valid/path1", "/valid/path2"]
        let tags = ["important", "quarterly"]
        
        mockFileManager.fileExistsHandler = { _ in true }
        mockFileManager.isReadableHandler = { _ in true }
        mockSecurityService.hasAccessHandler = { _ in true }
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 0, output: """
                [{
                    "id": "\(snapshot.id)",
                    "time": "2025-02-09T09:21:17Z",
                    "paths": ["/test"],
                    "tags": ["test"]
                }]
                """)
        }
        
        // Act & Assert
        try await sut.validateSnapshotOperation(
            repository: repository,
            snapshot: snapshot,
            paths: paths,
            tags: tags
        )
    }
    
    @Test("Validation chain fails appropriately on first error")
    func testValidationChainFailure() async {
        // Arrange
        let repository = Repository.mock()
        let paths = ["/invalid/path"]
        let tags = ["invalid tag with spaces"]
        
        mockFileManager.fileExistsHandler = { _ in false }
        
        // Act & Assert - Should fail on path validation before reaching tag validation
        await #expect(throws: ValidationError.pathNotFound(path: paths[0])) {
            try await sut.validateBackupOperation(
                repository: repository,
                paths: paths,
                tags: tags
            )
        }
    }
    
    @Test("Cross-component validation with security checks")
    func testCrossComponentValidation() async throws {
        // Arrange
        let repository = Repository.mock()
        let paths = ["/secure/path"]
        
        // Test progressive security failures
        mockFileManager.fileExistsHandler = { _ in true }
        mockFileManager.isReadableHandler = { _ in true }
        
        // First test - Security access denied
        mockSecurityService.hasAccessHandler = { _ in false }
        await #expect(throws: ValidationError.insufficientPermissions(path: paths[0])) {
            try await sut.validateBackupOperation(
                repository: repository,
                paths: paths
            )
        }
        
        // Second test - Security access granted but repository inaccessible
        mockSecurityService.hasAccessHandler = { _ in true }
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 1, output: "repository not accessible")
        }
        
        await #expect(throws: ValidationError.repositoryNotAccessible(path: repository.path)) {
            try await sut.validateBackupOperation(
                repository: repository,
                paths: paths
            )
        }
    }
}

// MARK: - Mock Services

private final class MockSecurityService: SecurityServiceProtocol {
    var hasAccessHandler: ((URL) -> Bool)?
    
    func hasAccess(to url: URL) async -> Bool {
        hasAccessHandler?(url) ?? false
    }
}

private final class MockFileManager: FileManager {
    var fileExistsHandler: ((String) -> Bool)?
    var isReadableHandler: ((String) -> Bool)?
    var attributesHandler: ((String) -> [FileAttributeKey: Any])?
    
    override func fileExists(atPath path: String) -> Bool {
        fileExistsHandler?(path) ?? false
    }
    
    override func isReadableFile(atPath path: String) -> Bool {
        isReadableHandler?(path) ?? false
    }
    
    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        attributesHandler?(path) ?? [:]
    }
}

// MARK: - Test Helpers

private extension Repository {
    static func mock() -> Repository {
        Repository(
            path: "/test/repo",
            credentials: .mock(),
            settings: .mock(),
            options: nil
        )
    }
}

private extension RepositoryCredentials {
    static func mock() -> RepositoryCredentials {
        RepositoryCredentials(
            password: "test-password",
            keyFile: nil
        )
    }
}

private extension RepositorySettings {
    static func mock() -> RepositorySettings {
        RepositorySettings(
            backupSources: ["/test"],
            excludePatterns: nil,
            includePatterns: nil,
            tags: nil,
            compressionLevel: 6,
            chunkSize: 1024 * 1024
        )
    }
}

private extension ResticSnapshot {
    static func mock() -> ResticSnapshot {
        ResticSnapshot(
            id: "test-snapshot-id",
            time: Date(),
            paths: ["/test"],
            tags: ["test"]
        )
    }
}
