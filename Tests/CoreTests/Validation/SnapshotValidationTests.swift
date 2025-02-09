@testable import Core
import Testing

/// Tests for snapshot validation functionality
struct SnapshotValidationTests {
    let mockLogger = MockLogger()
    let mockXPCService = MockXPCService()
    
    var sut: ResticCommandService {
        ResticCommandService(
            xpcService: mockXPCService,
            logger: mockLogger
        )
    }
    
    @Test("validateSnapshotParameters validates valid parameters")
    func testValidateSnapshotParametersValid() async throws {
        // Arrange
        let repository = Repository.mock()
        let snapshot = ResticSnapshot.mock()
        let path = "/valid/path"
        let tags = ["backup", "test"]
        
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 0, output: """
                [{
                    "id": "\(snapshot.id)",
                    "time": "2025-02-09T09:16:49Z",
                    "paths": ["/test"],
                    "tags": ["test"]
                }]
                """)
        }
        
        // Act & Assert
        #expect(try await sut.validateSnapshotParameters(
            repository: repository,
            snapshot: snapshot,
            path: path,
            tags: tags
        ) == nil)
    }
    
    @Test("validateSnapshotParameters throws on invalid snapshot ID")
    func testValidateSnapshotParametersInvalidId() async {
        // Arrange
        let repository = Repository.mock()
        var snapshot = ResticSnapshot.mock()
        snapshot.id = ""
        
        // Act & Assert
        await #expect(throws: ValidationError.invalidSnapshotId) {
            try await sut.validateSnapshotParameters(
                repository: repository,
                snapshot: snapshot
            )
        }
    }
    
    @Test("validateSnapshotParameters throws when snapshot not found")
    func testValidateSnapshotParametersNotFound() async {
        // Arrange
        let repository = Repository.mock()
        let snapshot = ResticSnapshot.mock()
        
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 0, output: "[]")
        }
        
        // Act & Assert
        await #expect(throws: ValidationError.snapshotNotFound(id: snapshot.id)) {
            try await sut.validateSnapshotParameters(
                repository: repository,
                snapshot: snapshot
            )
        }
    }
    
    @Test("validateSnapshotParameters validates tags correctly")
    func testValidateSnapshotParametersTags() async {
        // Arrange
        let repository = Repository.mock()
        
        // Act & Assert - Valid tags
        try await sut.validateSnapshotParameters(
            repository: repository,
            tags: ["valid-tag", "another_tag", "tag123"]
        )
        
        // Invalid tags
        await #expect(throws: ValidationError.emptyTag) {
            try await sut.validateSnapshotParameters(
                repository: repository,
                tags: ["valid", ""]
            )
        }
        
        await #expect(throws: ValidationError.invalidTagFormat(tag: "invalid tag")) {
            try await sut.validateSnapshotParameters(
                repository: repository,
                tags: ["invalid tag"]
            )
        }
        
        await #expect(throws: ValidationError.invalidTagFormat(tag: "invalid@tag")) {
            try await sut.validateSnapshotParameters(
                repository: repository,
                tags: ["invalid@tag"]
            )
        }
    }
    
    @Test("validateSnapshotParameters handles invalid paths")
    func testValidateSnapshotParametersInvalidPath() async {
        // Arrange
        let repository = Repository.mock()
        
        // Act & Assert
        await #expect(throws: ValidationError.emptyPath) {
            try await sut.validateSnapshotParameters(
                repository: repository,
                path: ""
            )
        }
        
        await #expect(throws: ValidationError.pathNotFound(path: "/nonexistent/path")) {
            try await sut.validateSnapshotParameters(
                repository: repository,
                path: "/nonexistent/path"
            )
        }
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
