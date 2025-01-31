//
//  RepositoryCreationViewModelTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

@MainActor
struct RepositoryCreationViewModelTests {
    // MARK: - Test Setup
    
    struct TestContext {
        let creationService: TestMocks.MockRepositoryCreationService
        let viewModel: RepositoryCreationViewModel
        
        init() {
            self.creationService = TestMocks.MockRepositoryCreationService()
            self.viewModel = RepositoryCreationViewModel(creationService: creationService)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate repository creation with empty name", tags: ["validation", "model"])
    func testValidationEmptyName() throws {
        // Given
        let context = TestContext()
        context.viewModel.name = ""
        context.viewModel.path = "/test/path"
        context.viewModel.password = "test-password"
        context.viewModel.confirmPassword = "test-password"
        context.viewModel.mode = .create
        
        // Then
        #expect(!context.viewModel.isValid)
    }
    
    @Test("Validate repository creation with empty path", tags: ["validation", "model"])
    func testValidationEmptyPath() throws {
        // Given
        let context = TestContext()
        context.viewModel.name = "Test Repo"
        context.viewModel.path = ""
        context.viewModel.password = "test-password"
        context.viewModel.confirmPassword = "test-password"
        context.viewModel.mode = .create
        
        // Then
        #expect(!context.viewModel.isValid)
    }
    
    @Test("Validate repository creation with empty password", tags: ["validation", "model"])
    func testValidationEmptyPassword() throws {
        // Given
        let context = TestContext()
        context.viewModel.name = "Test Repo"
        context.viewModel.path = "/test/path"
        context.viewModel.password = ""
        context.viewModel.confirmPassword = ""
        context.viewModel.mode = .create
        
        // Then
        #expect(!context.viewModel.isValid)
    }
    
    @Test("Validate repository creation with mismatched passwords", tags: ["validation", "model"])
    func testValidationPasswordMismatch() throws {
        // Given
        let context = TestContext()
        context.viewModel.name = "Test Repo"
        context.viewModel.path = "/test/path"
        context.viewModel.password = "test-password"
        context.viewModel.confirmPassword = "different-password"
        context.viewModel.mode = .create
        
        // Then
        #expect(!context.viewModel.isValid)
    }
    
    @Test("Validate repository import mode", tags: ["validation", "model"])
    func testValidationImportMode() throws {
        // Given
        let context = TestContext()
        context.viewModel.name = "Test Repo"
        context.viewModel.path = "/test/path"
        context.viewModel.password = "test-password"
        context.viewModel.confirmPassword = "different-password" // Should be ignored in import mode
        context.viewModel.mode = .import
        
        // Then
        #expect(context.viewModel.isValid)
    }
    
    // MARK: - Creation Tests
    
    @Test("Create new repository successfully", tags: ["creation", "model"])
    func testCreateSuccess() async throws {
        // Given
        let context = TestContext()
        context.viewModel.name = "Test Repo"
        context.viewModel.path = "/test/path"
        context.viewModel.password = "test-password"
        context.viewModel.confirmPassword = "test-password"
        context.viewModel.mode = .create
        
        let expectedRepo = Repository(name: context.viewModel.name, path: URL(fileURLWithPath: context.viewModel.path))
        context.creationService.createResult = expectedRepo
        
        // When
        await context.viewModel.createOrImport()
        
        // Then
        if case .success(let repository) = context.viewModel.state {
            #expect(repository.id == expectedRepo.id)
            #expect(repository.name == expectedRepo.name)
            #expect(repository.path == expectedRepo.path)
        } else {
            #expect(false, "Expected success state with repository")
        }
    }
    
    @Test("Handle repository creation failure", tags: ["creation", "model", "error"])
    func testCreateFailure() async throws {
        // Given
        let context = TestContext()
        context.viewModel.name = "Test Repo"
        context.viewModel.path = "/test/path"
        context.viewModel.password = "test-password"
        context.viewModel.confirmPassword = "test-password"
        context.viewModel.mode = .create
        
        let expectedError = RepositoryCreationError.invalidPath("Test error")
        context.creationService.createError = expectedError
        
        // When
        await context.viewModel.createOrImport()
        
        // Then
        if case .error(let error as RepositoryCreationError) = context.viewModel.state {
            #expect(error.localizedDescription == expectedError.localizedDescription)
        } else {
            #expect(false, "Expected error state")
        }
    }
    
    // MARK: - Import Tests
    
    @Test("Import existing repository successfully", tags: ["import", "model"])
    func testImportSuccess() async throws {
        // Given
        let context = TestContext()
        context.viewModel.name = "Test Repo"
        context.viewModel.path = "/test/path"
        context.viewModel.password = "test-password"
        context.viewModel.mode = .import
        
        let expectedRepo = Repository(name: context.viewModel.name, path: URL(fileURLWithPath: context.viewModel.path))
        context.creationService.importResult = expectedRepo
        
        // When
        await context.viewModel.createOrImport()
        
        // Then
        if case .success(let repository) = context.viewModel.state {
            #expect(repository.id == expectedRepo.id)
            #expect(repository.name == expectedRepo.name)
            #expect(repository.path == expectedRepo.path)
        } else {
            #expect(false, "Expected success state with repository")
        }
    }
    
    @Test("Handle repository import failure", tags: ["import", "model", "error"])
    func testImportFailure() async throws {
        // Given
        let context = TestContext()
        context.viewModel.name = "Test Repo"
        context.viewModel.path = "/test/path"
        context.viewModel.password = "test-password"
        context.viewModel.mode = .import
        
        let expectedError = RepositoryCreationError.invalidPath("Test error")
        context.creationService.importError = expectedError
        
        // When
        await context.viewModel.createOrImport()
        
        // Then
        if case .error(let error as RepositoryCreationError) = context.viewModel.state {
            #expect(error.localizedDescription == expectedError.localizedDescription)
        } else {
            #expect(false, "Expected error state")
        }
    }
}
