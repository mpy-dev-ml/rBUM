//
//  RepositoryCreationViewModelTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
@testable import rBUM

@MainActor
final class RepositoryCreationViewModelTests: XCTestCase {
    fileprivate var viewModel: RepositoryCreationViewModel!
    fileprivate var mockCreationService: MockRepositoryCreationService!
    fileprivate var testPath: String!
    
    override func setUp() async throws {
        mockCreationService = MockRepositoryCreationService()
        viewModel = RepositoryCreationViewModel(creationService: mockCreationService)
        testPath = "/test/path"
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockCreationService = nil
        testPath = nil
    }
    
    func testCreateRepository() async throws {
        // Given
        viewModel.mode = .create
        viewModel.name = "Test Repo"
        viewModel.path = testPath
        viewModel.password = "test-password"
        viewModel.confirmPassword = "test-password"
        
        let expectedRepo = Repository(name: "Test Repo", path: URL(filePath: testPath))
        mockCreationService.createResult = expectedRepo
        
        // When
        await viewModel.createOrImport()
        
        // Then
        XCTAssertTrue(mockCreationService.createCalled)
        XCTAssertEqual(mockCreationService.createName, "Test Repo")
        XCTAssertEqual(mockCreationService.createPath?.path(), testPath)
        XCTAssertEqual(mockCreationService.createPassword, "test-password")
        
        if case .success(let repository) = viewModel.state {
            XCTAssertEqual(repository.id, expectedRepo.id)
            XCTAssertEqual(repository.name, expectedRepo.name)
            XCTAssertEqual(repository.path, expectedRepo.path)
        } else {
            XCTFail("Expected success state")
        }
    }
    
    func testImportRepository() async throws {
        // Given
        viewModel.mode = .import
        viewModel.name = "Test Repo"
        viewModel.path = testPath
        viewModel.password = "test-password"
        
        let expectedRepo = Repository(name: "Test Repo", path: URL(filePath: testPath))
        mockCreationService.importResult = expectedRepo
        
        // When
        await viewModel.createOrImport()
        
        // Then
        XCTAssertTrue(mockCreationService.importCalled)
        XCTAssertEqual(mockCreationService.importName, "Test Repo")
        XCTAssertEqual(mockCreationService.importPath?.path(), testPath)
        XCTAssertEqual(mockCreationService.importPassword, "test-password")
        
        if case .success(let repository) = viewModel.state {
            XCTAssertEqual(repository.id, expectedRepo.id)
            XCTAssertEqual(repository.name, expectedRepo.name)
            XCTAssertEqual(repository.path, expectedRepo.path)
        } else {
            XCTFail("Expected success state")
        }
    }
    
    func testValidation() {
        // Given/When empty fields
        XCTAssertFalse(viewModel.isValid)
        
        // When partial fields
        viewModel.name = "Test"
        XCTAssertFalse(viewModel.isValid)
        
        viewModel.path = testPath
        XCTAssertFalse(viewModel.isValid)
        
        // When create mode without confirm
        viewModel.mode = .create
        viewModel.password = "test"
        XCTAssertFalse(viewModel.isValid)
        
        // When create mode with matching confirm
        viewModel.confirmPassword = "test"
        XCTAssertTrue(viewModel.isValid)
        
        // When import mode
        viewModel.mode = .import
        viewModel.confirmPassword = ""
        XCTAssertTrue(viewModel.isValid)
    }
    
    func testCreateError() async throws {
        // Given
        viewModel.mode = .create
        viewModel.name = "Test Repo"
        viewModel.path = testPath
        viewModel.password = "test-password"
        viewModel.confirmPassword = "test-password"
        
        let expectedError = RepositoryCreationError.pathAlreadyExists
        mockCreationService.createError = expectedError
        
        // When
        await viewModel.createOrImport()
        
        // Then
        if case .error(let error) = viewModel.state {
            XCTAssertEqual(error as? RepositoryCreationError, expectedError)
            XCTAssertTrue(viewModel.showError)
        } else {
            XCTFail("Expected error state")
        }
    }
}

// MARK: - Mocks

private final class MockRepositoryCreationService: RepositoryCreationServiceProtocol {
    var createResult: Repository?
    var importResult: Repository?
    var createError: Error?
    var importError: Error?
    
    var createCalled = false
    var importCalled = false
    
    var createName: String?
    var createPath: URL?
    var createPassword: String?
    
    var importName: String?
    var importPath: URL?
    var importPassword: String?
    
    func createRepository(name: String, path: URL, password: String) async throws -> Repository {
        createCalled = true
        createName = name
        createPath = path
        createPassword = password
        
        if let error = createError {
            throw error
        }
        
        return createResult ?? Repository(name: name, path: path)
    }
    
    func importRepository(name: String, path: URL, password: String) async throws -> Repository {
        importCalled = true
        importName = name
        importPath = path
        importPassword = password
        
        if let error = importError {
            throw error
        }
        
        return importResult ?? Repository(name: name, path: path)
    }
}
