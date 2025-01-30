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
    var creationService: TestMocks.MockRepositoryCreationService!
    var sut: RepositoryCreationViewModel!
    
    override func setUpWithError() throws {
        creationService = TestMocks.MockRepositoryCreationService()
        sut = RepositoryCreationViewModel(creationService: creationService)
    }
    
    override func tearDownWithError() throws {
        creationService = nil
        sut = nil
    }
    
    func test_isValid_emptyName() {
        // Given
        sut.name = ""
        sut.path = "/test/path"
        sut.password = "test-password"
        sut.confirmPassword = "test-password"
        sut.mode = .create
        
        // Then
        XCTAssertFalse(sut.isValid)
    }
    
    func test_isValid_emptyPath() {
        // Given
        sut.name = "Test Repo"
        sut.path = ""
        sut.password = "test-password"
        sut.confirmPassword = "test-password"
        sut.mode = .create
        
        // Then
        XCTAssertFalse(sut.isValid)
    }
    
    func test_isValid_emptyPassword() {
        // Given
        sut.name = "Test Repo"
        sut.path = "/test/path"
        sut.password = ""
        sut.confirmPassword = ""
        sut.mode = .create
        
        // Then
        XCTAssertFalse(sut.isValid)
    }
    
    func test_isValid_passwordMismatch() {
        // Given
        sut.name = "Test Repo"
        sut.path = "/test/path"
        sut.password = "test-password"
        sut.confirmPassword = "different-password"
        sut.mode = .create
        
        // Then
        XCTAssertFalse(sut.isValid)
    }
    
    func test_isValid_importMode() {
        // Given
        sut.name = "Test Repo"
        sut.path = "/test/path"
        sut.password = "test-password"
        sut.confirmPassword = "different-password" // Should be ignored in import mode
        sut.mode = .import
        
        // Then
        XCTAssertTrue(sut.isValid)
    }
    
    func test_createOrImport_create_success() async {
        // Given
        sut.name = "Test Repo"
        sut.path = "/test/path"
        sut.password = "test-password"
        sut.confirmPassword = "test-password"
        sut.mode = .create
        
        let expectedRepo = Repository(name: sut.name, path: URL(fileURLWithPath: sut.path))
        creationService.createResult = expectedRepo
        
        // When
        await sut.createOrImport()
        
        // Then
        if case .success(let repository) = sut.state {
            XCTAssertEqual(repository.id, expectedRepo.id)
            XCTAssertEqual(repository.name, expectedRepo.name)
            XCTAssertEqual(repository.path, expectedRepo.path)
        } else {
            XCTFail("Expected success state with repository")
        }
    }
    
    func test_createOrImport_create_failure() async {
        // Given
        sut.name = "Test Repo"
        sut.path = "/test/path"
        sut.password = "test-password"
        sut.confirmPassword = "test-password"
        sut.mode = .create
        
        let expectedError = RepositoryCreationError.invalidPath("Test error")
        creationService.createError = expectedError
        
        // When
        await sut.createOrImport()
        
        // Then
        if case .error(let error as RepositoryCreationError) = sut.state {
            XCTAssertEqual(error.localizedDescription, expectedError.localizedDescription)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func test_createOrImport_import_success() async {
        // Given
        sut.name = "Test Repo"
        sut.path = "/test/path"
        sut.password = "test-password"
        sut.mode = .import
        
        let expectedRepo = Repository(name: sut.name, path: URL(fileURLWithPath: sut.path))
        creationService.importResult = expectedRepo
        
        // When
        await sut.createOrImport()
        
        // Then
        if case .success(let repository) = sut.state {
            XCTAssertEqual(repository.id, expectedRepo.id)
            XCTAssertEqual(repository.name, expectedRepo.name)
            XCTAssertEqual(repository.path, expectedRepo.path)
        } else {
            XCTFail("Expected success state with repository")
        }
    }
    
    func test_createOrImport_import_failure() async {
        // Given
        sut.name = "Test Repo"
        sut.path = "/test/path"
        sut.password = "test-password"
        sut.mode = .import
        
        let expectedError = RepositoryCreationError.invalidPath("Test error")
        creationService.importError = expectedError
        
        // When
        await sut.createOrImport()
        
        // Then
        if case .error(let error as RepositoryCreationError) = sut.state {
            XCTAssertEqual(error.localizedDescription, expectedError.localizedDescription)
        } else {
            XCTFail("Expected error state")
        }
    }
}
