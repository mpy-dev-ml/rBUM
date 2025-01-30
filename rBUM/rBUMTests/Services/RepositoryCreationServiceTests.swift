//
//  RepositoryCreationServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
@testable import rBUM

@MainActor
final class RepositoryCreationServiceTests: XCTestCase {
    var resticService: TestMocks.MockResticCommandService!
    var repositoryStorage: TestMocks.MockRepositoryStorage!
    var fileManager: FileManager!
    var sut: rBUM.RepositoryCreationService!
    
    override func setUpWithError() throws {
        resticService = TestMocks.MockResticCommandService()
        repositoryStorage = TestMocks.MockRepositoryStorage()
        fileManager = FileManager.default
        sut = rBUM.RepositoryCreationService(
            resticService: resticService,
            repositoryStorage: repositoryStorage,
            fileManager: fileManager
        )
    }
    
    override func tearDownWithError() throws {
        resticService = nil
        repositoryStorage = nil
        fileManager = nil
        sut = nil
    }
    
    func test_createRepository_success() async throws {
        // Given
        let path = URL(fileURLWithPath: "/test/path")
        let name = "Test Repository"
        let password = "test-password"
        
        // When
        let repository = try await sut.createRepository(
            name: name,
            path: path,
            password: password
        )
        
        // Then
        XCTAssertEqual(repository.name, name)
        XCTAssertEqual(repository.path, path)
    }
    
    func test_createRepository_pathExists() async throws {
        // Given
        let path = URL(fileURLWithPath: "/test/path")
        repositoryStorage.existsResult = true
        
        // When/Then
        do {
            _ = try await sut.createRepository(
                name: "Test",
                path: path,
                password: "test"
            )
            XCTFail("Expected error to be thrown")
        } catch let error as rBUM.RepositoryCreationError {
            XCTAssertEqual(error, .repositoryAlreadyExists)
        }
    }
    
    func test_createRepository_initializationFails() async throws {
        // Given
        let path = URL(fileURLWithPath: "/test/path")
        resticService.initError = NSError(domain: "test", code: 1)
        
        // When/Then
        do {
            _ = try await sut.createRepository(
                name: "Test",
                path: path,
                password: "test"
            )
            XCTFail("Expected error to be thrown")
        } catch let error as rBUM.RepositoryCreationError {
            XCTAssertEqual(error, .creationFailed("Failed to initialize repository"))
        }
    }
    
    func test_importRepository_success() async throws {
        // Given
        let path = URL(fileURLWithPath: "/test/path")
        let name = "Test Repository"
        let password = "test-password"
        
        // When
        let repository = try await sut.importRepository(
            name: name,
            path: path,
            password: password
        )
        
        // Then
        XCTAssertEqual(repository.name, name)
        XCTAssertEqual(repository.path, path)
    }
    
    func test_importRepository_pathExists() async throws {
        // Given
        let path = URL(fileURLWithPath: "/test/path")
        repositoryStorage.existsResult = true
        
        // When/Then
        do {
            _ = try await sut.importRepository(
                name: "Test",
                path: path,
                password: "test"
            )
            XCTFail("Expected error to be thrown")
        } catch let error as rBUM.RepositoryCreationError {
            XCTAssertEqual(error, .repositoryAlreadyExists)
        }
    }
    
    func test_importRepository_validationFails() async throws {
        // Given
        let path = URL(fileURLWithPath: "/test/path")
        resticService.checkError = NSError(domain: "test", code: 1)
        
        // When/Then
        do {
            _ = try await sut.importRepository(
                name: "Test",
                path: path,
                password: "test"
            )
            XCTFail("Expected error to be thrown")
        } catch let error as rBUM.RepositoryCreationError {
            XCTAssertEqual(error, .importFailed("Failed to validate repository"))
        }
    }
}
