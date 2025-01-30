//
//  RepositoryCreationServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
@testable import rBUM

final class RepositoryCreationServiceTests: XCTestCase {
    fileprivate var service: RepositoryCreationService!
    fileprivate var mockResticService: MockResticCommandService!
    fileprivate var mockRepositoryStorage: MockRepositoryStorage!
    fileprivate var mockFileManager: MockFileManager!
    fileprivate var testDirectory: URL!
    
    override func setUp() async throws {
        // Set up test dependencies
        mockResticService = MockResticCommandService()
        mockRepositoryStorage = MockRepositoryStorage()
        mockFileManager = MockFileManager()
        
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev.mpy.rBUM.tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        service = RepositoryCreationService(
            resticService: mockResticService,
            repositoryStorage: mockRepositoryStorage,
            fileManager: mockFileManager
        )
    }
    
    override func tearDown() async throws {
        // Clean up test dependencies
        service = nil
        mockResticService = nil
        mockRepositoryStorage = nil
        mockFileManager = nil
        testDirectory = nil
    }
    
    func testCreateRepository() async throws {
        // Given
        let name = "Test Repo"
        let path = testDirectory.appendingPathComponent("repo")
        let password = "test-password"
        
        mockFileManager.fileExistsResult = false
        mockFileManager.createDirectoryError = nil
        mockResticService.initializeError = nil
        mockRepositoryStorage.storeError = nil
        
        // When
        let repository = try await service.createRepository(
            name: name,
            path: path,
            password: password
        )
        
        // Then
        XCTAssertEqual(repository.name, name)
        XCTAssertEqual(repository.path, path)
        XCTAssertTrue(mockFileManager.createDirectoryCalled)
        XCTAssertTrue(mockResticService.initializeCalled)
        XCTAssertTrue(mockRepositoryStorage.storeCalled)
    }
    
    func testCreateRepositoryAtExistingPath() async throws {
        // Given
        let path = testDirectory.appendingPathComponent("repo")
        mockFileManager.fileExistsResult = true
        
        // When/Then
        do {
            _ = try await service.createRepository(
                name: "Test",
                path: path,
                password: "test"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? RepositoryCreationError, .pathAlreadyExists)
        }
    }
    
    func testImportRepository() async throws {
        // Given
        let name = "Test Repo"
        let path = testDirectory.appendingPathComponent("repo")
        let password = "test-password"
        
        mockFileManager.fileExistsResult = true
        mockResticService.checkResult = true
        mockRepositoryStorage.existsResult = false
        mockRepositoryStorage.storeError = nil
        
        // When
        let repository = try await service.importRepository(
            name: name,
            path: path,
            password: password
        )
        
        // Then
        XCTAssertEqual(repository.name, name)
        XCTAssertEqual(repository.path, path)
        XCTAssertTrue(mockResticService.checkCalled)
        XCTAssertTrue(mockRepositoryStorage.storeCalled)
    }
    
    func testImportInvalidRepository() async throws {
        // Given
        let path = testDirectory.appendingPathComponent("repo")
        mockFileManager.fileExistsResult = true
        mockResticService.checkResult = false
        
        // When/Then
        do {
            _ = try await service.importRepository(
                name: "Test",
                path: path,
                password: "test"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? RepositoryCreationError, .invalidRepository)
        }
    }
    
    func testImportAlreadyImportedRepository() async throws {
        // Given
        let path = testDirectory.appendingPathComponent("repo")
        mockFileManager.fileExistsResult = true
        mockRepositoryStorage.existsResult = true
        
        // When/Then
        do {
            _ = try await service.importRepository(
                name: "Test",
                path: path,
                password: "test"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? RepositoryCreationError, .repositoryAlreadyExists)
        }
    }
}

// MARK: - Mocks

private final class MockResticCommandService: ResticCommandServiceProtocol {
    var initializeError: Error?
    var checkResult = false
    var initializeCalled = false
    var checkCalled = false
    
    func initializeRepository(_ repository: Repository, password: String) async throws {
        initializeCalled = true
        if let error = initializeError {
            throw error
        }
    }
    
    func checkRepository(_ repository: Repository) async throws -> Bool {
        checkCalled = true
        if !checkResult {
            throw ResticError.invalidRepository
        }
        return true
    }
    
    func createBackup(for repository: Repository, paths: [String]) async throws {
        // Not used in these tests
    }
}

private final class MockRepositoryStorage: RepositoryStorageProtocol {
    var storeError: Error?
    var existsResult = false
    var storeCalled = false
    var existsCalled = false
    
    func store(_ repository: Repository) throws {
        storeCalled = true
        if let error = storeError {
            throw error
        }
    }
    
    func retrieve(forId id: UUID) throws -> Repository? {
        return nil
    }
    
    func list() throws -> [Repository] {
        return []
    }
    
    func delete(forId id: UUID) throws {}
    
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool {
        existsCalled = true
        return existsResult
    }
}

private final class MockFileManager: FileManager {
    var fileExistsResult = false
    var createDirectoryError: Error?
    var createDirectoryCalled = false
    
    override func fileExists(atPath path: String) -> Bool {
        return fileExistsResult
    }
    
    override func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey : Any]?) throws {
        createDirectoryCalled = true
        if let error = createDirectoryError {
            throw error
        }
    }
}
