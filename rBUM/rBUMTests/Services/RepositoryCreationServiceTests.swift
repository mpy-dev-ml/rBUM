//
//  RepositoryCreationServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

@MainActor
struct RepositoryCreationServiceTests {
    // MARK: - Test Setup
    
    struct TestContext {
        let resticService: TestMocks.MockResticCommandService
        let repositoryStorage: TestMocks.MockRepositoryStorage
        let fileManager: FileManager
        let sut: rBUM.RepositoryCreationService
        
        init() {
            self.resticService = TestMocks.MockResticCommandService()
            self.repositoryStorage = TestMocks.MockRepositoryStorage()
            self.fileManager = FileManager.default
            self.sut = rBUM.RepositoryCreationService(
                resticService: resticService,
                repositoryStorage: repositoryStorage,
                fileManager: fileManager
            )
        }
    }
    
    // MARK: - Repository Creation Tests
    
    @Test("Create repository with various configurations",
          .tags(.core, .integration, .repository),
          arguments: [
              (name: "Test Repository", path: "/test/path", password: "test-password"),
              (name: "Backup Repo", path: "/backup/path", password: "complex!@#$%^&*()"),
              (name: "System Backup", path: "/system/backup", password: "pass with spaces")
          ])
    func testCreateRepository(name: String, path: String, password: String) async throws {
        // Given
        let context = TestContext()
        let repositoryPath = URL(fileURLWithPath: path)
        
        // When
        let repository = try await context.sut.createRepository(
            name: name,
            path: repositoryPath,
            password: password
        )
        
        // Then
        #expect(repository.name == name)
        #expect(repository.path == repositoryPath)
        #expect(try await context.repositoryStorage.exists(at: repositoryPath) == false)
    }
    
    @Test("Handle repository creation errors",
          .tags(.core, .integration, .repository, .error_handling),
          arguments: [
              (exists: true, initError: nil, expectedError: RepositoryCreationError.repositoryAlreadyExists),
              (exists: false, initError: NSError(domain: "test", code: 1), expectedError: RepositoryCreationError.creationFailed("Failed to initialize repository"))
          ])
    func testCreateRepositoryErrors(exists: Bool, initError: Error?, expectedError: RepositoryCreationError) async throws {
        // Given
        let context = TestContext()
        let path = URL(fileURLWithPath: "/test/path")
        context.repositoryStorage.existsResult = exists
        if let error = initError {
            context.resticService.initError = error
        }
        
        // When/Then
        await #expect(throws: expectedError) {
            _ = try await context.sut.createRepository(
                name: "Test",
                path: path,
                password: "test"
            )
        }
    }
    
    // MARK: - Repository Import Tests
    
    @Test("Import existing repository with various configurations",
          .tags(.core, .integration, .repository),
          arguments: [
              (name: "Imported Repo", path: "/existing/path", password: "test-password"),
              (name: "External Backup", path: "/external/backup", password: "complex!@#$%^&*()"),
              (name: "Network Backup", path: "/network/path", password: "pass with spaces")
          ])
    func testImportRepository(name: String, path: String, password: String) async throws {
        // Given
        let context = TestContext()
        let repositoryPath = URL(fileURLWithPath: path)
        
        // When
        let repository = try await context.sut.importRepository(
            name: name,
            path: repositoryPath,
            password: password
        )
        
        // Then
        #expect(repository.name == name)
        #expect(repository.path == repositoryPath)
        #expect(try await context.repositoryStorage.exists(at: repositoryPath) == false)
    }
    
    @Test("Handle repository import errors",
          .tags(.core, .integration, .repository, .error_handling),
          arguments: [
              (exists: true, checkError: nil, expectedError: RepositoryCreationError.repositoryAlreadyExists),
              (exists: false, checkError: NSError(domain: "test", code: 1), expectedError: RepositoryCreationError.importFailed("Failed to validate repository"))
          ])
    func testImportRepositoryErrors(exists: Bool, checkError: Error?, expectedError: RepositoryCreationError) async throws {
        // Given
        let context = TestContext()
        let path = URL(fileURLWithPath: "/test/path")
        context.repositoryStorage.existsResult = exists
        if let error = checkError {
            context.resticService.checkError = error
        }
        
        // When/Then
        await #expect(throws: expectedError) {
            _ = try await context.sut.importRepository(
                name: "Test",
                path: path,
                password: "test"
            )
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle special characters in repository paths",
          .tags(.core, .integration, .repository, .validation))
    func testSpecialCharactersInPath() async throws {
        // Given
        let context = TestContext()
        let paths = [
            "/path with spaces/repo",
            "/path/with/special/chars/!@#$%",
            "/path/with/unicode/"
        ]
        
        // Then
        for path in paths {
            // When
            let repository = try await context.sut.createRepository(
                name: "Test Repository",
                path: URL(fileURLWithPath: path),
                password: "test-password"
            )
            
            #expect(repository.path.path == path)
        }
    }
    
    @Test("Handle very long repository names and paths",
          .tags(.core, .integration, .repository, .validation))
    func testLongNamesAndPaths() async throws {
        // Given
        let context = TestContext()
        let longName = String(repeating: "a", count: 255)
        let longPath = "/\(String(repeating: "directory/", count: 50))repository"
        
        // When
        let repository = try await context.sut.createRepository(
            name: longName,
            path: URL(fileURLWithPath: longPath),
            password: "test-password"
        )
        
        // Then
        #expect(repository.name == longName)
        #expect(repository.path.path == longPath)
    }
}
