@testable import Core
import Testing

/// Tests for path validation functionality
struct PathValidationTests {
    let mockLogger = MockLogger()
    let mockXPCService = MockXPCService()
    let mockFileManager = MockFileManager()
    
    var sut: ResticCommandService {
        ResticCommandService(
            xpcService: mockXPCService,
            logger: mockLogger,
            fileManager: mockFileManager
        )
    }
    
    @Test("validatePath accepts valid paths")
    func testValidatePathValid() async throws {
        // Arrange
        let validPath = "/valid/test/path"
        mockFileManager.fileExistsHandler = { path in
            path == validPath
        }
        mockFileManager.isReadableHandler = { path in
            path == validPath
        }
        
        // Act & Assert
        #expect(try await sut.validatePath(validPath) == nil)
    }
    
    @Test("validatePath rejects empty paths")
    func testValidatePathEmpty() async {
        // Act & Assert
        await #expect(throws: ValidationError.emptyPath) {
            try await sut.validatePath("")
        }
    }
    
    @Test("validatePath rejects nonexistent paths")
    func testValidatePathNonexistent() async {
        // Arrange
        let nonexistentPath = "/nonexistent/path"
        mockFileManager.fileExistsHandler = { _ in false }
        
        // Act & Assert
        await #expect(throws: ValidationError.pathNotFound(path: nonexistentPath)) {
            try await sut.validatePath(nonexistentPath)
        }
    }
    
    @Test("validatePath rejects inaccessible paths")
    func testValidatePathInaccessible() async {
        // Arrange
        let inaccessiblePath = "/inaccessible/path"
        mockFileManager.fileExistsHandler = { _ in true }
        mockFileManager.isReadableHandler = { _ in false }
        
        // Act & Assert
        await #expect(throws: ValidationError.pathNotAccessible(path: inaccessiblePath)) {
            try await sut.validatePath(inaccessiblePath)
        }
    }
    
    @Test("validatePath rejects paths with invalid characters")
    func testValidatePathInvalidCharacters() async {
        // Arrange
        let invalidPaths = [
            "/path/with/*/asterisk",
            "/path/with/?/question",
            "/path/with/:/colon",
            "/path/with/\"/quote",
            "/path/with/|/pipe",
            "/path/with/</angle",
            "/path/with/>/bracket"
        ]
        
        mockFileManager.fileExistsHandler = { _ in true }
        mockFileManager.isReadableHandler = { _ in true }
        
        // Act & Assert
        for path in invalidPaths {
            await #expect(throws: ValidationError.invalidPathFormat(path: path)) {
                try await sut.validatePath(path)
            }
        }
    }
    
    @Test("validatePath rejects paths that are too long")
    func testValidatePathTooLong() async {
        // Arrange
        let longPath = String(repeating: "a", count: 4097)
        mockFileManager.fileExistsHandler = { _ in true }
        mockFileManager.isReadableHandler = { _ in true }
        
        // Act & Assert
        await #expect(throws: ValidationError.pathTooLong(path: longPath)) {
            try await sut.validatePath(longPath)
        }
    }
    
    @Test("validateExcludePatterns accepts valid patterns")
    func testValidateExcludePatternsValid() async throws {
        // Arrange
        let validPatterns = [
            "*.txt",
            "temp/*",
            "backup-*",
            "test_pattern"
        ]
        
        // Act & Assert
        #expect(try await sut.validateExcludePatterns(validPatterns) == nil)
    }
    
    @Test("validateExcludePatterns rejects empty patterns")
    func testValidateExcludePatternsEmpty() async {
        // Act & Assert
        await #expect(throws: ValidationError.emptyExcludePattern) {
            try await sut.validateExcludePatterns(["valid", ""])
        }
    }
    
    @Test("validateExcludePatterns rejects patterns with invalid characters")
    func testValidateExcludePatternsInvalidCharacters() async {
        // Arrange
        let invalidPatterns = [
            "pattern:with:colons",
            "pattern\"with\"quotes",
            "pattern|with|pipes",
            "pattern<with>angles"
        ]
        
        // Act & Assert
        for pattern in invalidPatterns {
            await #expect(throws: ValidationError.invalidExcludePattern(pattern: pattern)) {
                try await sut.validateExcludePatterns([pattern])
            }
        }
    }
    
    @Test("validateExcludePatterns rejects patterns that are too long")
    func testValidateExcludePatternsTooLong() async {
        // Arrange
        let longPattern = String(repeating: "a", count: 1025)
        
        // Act & Assert
        await #expect(throws: ValidationError.excludePatternTooLong(pattern: longPattern)) {
            try await sut.validateExcludePatterns([longPattern])
        }
    }
}

// MARK: - Mock File Manager

private final class MockFileManager: FileManager {
    var fileExistsHandler: ((String) -> Bool)?
    var isReadableHandler: ((String) -> Bool)?
    
    override func fileExists(atPath path: String) -> Bool {
        fileExistsHandler?(path) ?? false
    }
    
    override func isReadableFile(atPath path: String) -> Bool {
        isReadableHandler?(path) ?? false
    }
}
