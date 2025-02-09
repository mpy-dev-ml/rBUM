@testable import Core
import Testing

/// Tests for core validation functionality
struct ValidationTests {
    let mockLogger = MockLogger()
    let mockXPCService = MockXPCService()
    
    var sut: ResticCommandService {
        ResticCommandService(
            xpcService: mockXPCService,
            logger: mockLogger
        )
    }
    
    @Test("validateRepository validates valid repository")
    func testValidateRepositoryValid() async throws {
        // Arrange
        let repository = Repository.mock()
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 0, output: "")
        }
        
        // Act & Assert
        #expect(try await sut.validateRepository(repository) == nil)
    }
    
    @Test("validateRepository throws on empty path")
    func testValidateRepositoryEmptyPath() async {
        // Arrange
        var repository = Repository.mock()
        repository.path = ""
        
        // Act & Assert
        await #expect(throws: ValidationError.emptyRepositoryPath) {
            try await sut.validateRepository(repository)
        }
    }
    
    @Test("validateRepository throws when repository not found")
    func testValidateRepositoryNotFound() async {
        // Arrange
        let repository = Repository.mock()
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 1, output: "")
        }
        
        // Act & Assert
        await #expect(throws: ValidationError.repositoryNotFound(path: repository.path)) {
            try await sut.validateRepository(repository)
        }
    }
    
    @Test("validateCredentials validates valid credentials")
    func testValidateCredentialsValid() async throws {
        // Arrange
        let credentials = RepositoryCredentials.mock()
        
        // Act & Assert
        #expect(try await sut.validateCredentials(credentials) == nil)
    }
    
    @Test("validateCredentials throws on empty password")
    func testValidateCredentialsEmptyPassword() async {
        // Arrange
        var credentials = RepositoryCredentials.mock()
        credentials.password = ""
        
        // Act & Assert
        await #expect(throws: ValidationError.emptyPassword) {
            try await sut.validateCredentials(credentials)
        }
    }
    
    @Test("validateKeyFile validates valid key file")
    func testValidateKeyFileValid() async throws {
        // Arrange
        let keyFilePath = "/valid/key/file"
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 0, output: "")
        }
        
        // Act & Assert
        #expect(try await sut.validateKeyFile(keyFilePath) == nil)
    }
    
    @Test("validateKeyFile throws on empty path")
    func testValidateKeyFileEmptyPath() async {
        // Act & Assert
        await #expect(throws: ValidationError.emptyKeyFilePath) {
            try await sut.validateKeyFile("")
        }
    }
    
    @Test("validateKeyFile throws when file not found")
    func testValidateKeyFileNotFound() async {
        // Arrange
        let keyFilePath = "/nonexistent/key/file"
        mockXPCService.executeHandler = { command, _ in
            if command == "which" {
                return ProcessResult(exitCode: 0, output: "/usr/local/bin/restic")
            }
            return ProcessResult(exitCode: 1, output: "")
        }
        
        // Act & Assert
        await #expect(throws: ValidationError.keyFileNotFound(path: keyFilePath)) {
            try await sut.validateKeyFile(keyFilePath)
        }
    }
}

// MARK: - Mock XPC Service

private final class MockXPCService: XPCServiceProtocol {
    var executeHandler: ((String, [String]) async throws -> ProcessResult)?
    
    func execute(command: String, arguments: [String]) async throws -> ProcessResult {
        try await executeHandler?(command, arguments) ?? ProcessResult(exitCode: 0, output: "")
    }
}

// MARK: - Mock Logger

private final class MockLogger: LoggerProtocol {
    func log(_ message: String, level: LogLevel) {}
    func error(_ error: Error) {}
}
