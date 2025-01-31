//
//  RepositoryCreationViewModelTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for RepositoryCreationViewModel functionality
@MainActor
struct RepositoryCreationViewModelTests {
    // MARK: - Test Context
    
    /// Test environment with mocked dependencies
    struct TestContext {
        let viewModel: RepositoryCreationViewModel
        let mockCreationService: MockRepositoryCreationService
        let mockFileManager: MockFileManager
        let mockNotificationCenter: MockNotificationCenter
        
        init() {
            self.mockCreationService = MockRepositoryCreationService()
            self.mockFileManager = MockFileManager()
            self.mockNotificationCenter = MockNotificationCenter()
            self.viewModel = RepositoryCreationViewModel(
                creationService: mockCreationService,
                fileManager: mockFileManager,
                notificationCenter: mockNotificationCenter
            )
        }
        
        /// Reset all mocks to initial state
        func reset() {
            mockCreationService.reset()
            mockFileManager.reset()
            mockNotificationCenter.reset()
        }
    }
    
    // MARK: - Repository Creation Tests
    
    @Test("Create repository successfully", tags: ["creation", "repository"])
    func testCreateRepositorySuccess() async throws {
        // Given: Valid repository configuration
        let context = TestContext()
        let repository = MockData.Repository.validRepository
        
        context.viewModel.name = repository.name
        context.viewModel.path = repository.path
        context.viewModel.password = MockData.Repository.validPassword
        context.mockCreationService.createResult = repository
        
        // When: Creating repository
        try await context.viewModel.createRepository()
        
        // Then: Repository is created without error
        #expect(context.mockCreationService.createCalled)
        #expect(!context.viewModel.isLoading)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
        #expect(context.mockNotificationCenter.postNotificationCalled)
    }
    
    @Test("Handle repository creation failure", tags: ["creation", "repository", "error"])
    func testCreateRepositoryFailure() async throws {
        // Given: Creation will fail
        let context = TestContext()
        let repository = MockData.Repository.validRepository
        
        context.viewModel.name = repository.name
        context.viewModel.path = repository.path
        context.viewModel.password = MockData.Repository.validPassword
        context.mockCreationService.shouldFail = true
        context.mockCreationService.error = MockData.Error.repositoryCreationError
        
        // When: Creating repository
        try await context.viewModel.createRepository()
        
        // Then: Error is handled properly
        #expect(context.mockCreationService.createCalled)
        #expect(!context.viewModel.isLoading)
        #expect(context.viewModel.showError)
        #expect(context.viewModel.error as? MockData.Error == MockData.Error.repositoryCreationError)
    }
    
    @Test("Validate repository path", tags: ["validation", "repository"])
    func testValidateRepositoryPath() async throws {
        // Given: Various paths
        let context = TestContext()
        let validPath = MockData.Repository.validPath
        let invalidPath = MockData.Repository.invalidPath
        
        // When/Then: Testing valid path
        context.viewModel.path = validPath
        context.mockFileManager.pathExists = true
        context.mockFileManager.isDirectory = true
        
        #expect(context.viewModel.isPathValid)
        #expect(!context.viewModel.showPathError)
        
        // When/Then: Testing invalid path
        context.viewModel.path = invalidPath
        context.mockFileManager.pathExists = false
        
        #expect(!context.viewModel.isPathValid)
        #expect(context.viewModel.showPathError)
    }
    
    @Test("Validate repository name", tags: ["validation", "repository"])
    func testValidateRepositoryName() async throws {
        // Given: Various names
        let context = TestContext()
        let validName = MockData.Repository.validName
        let invalidName = ""
        
        // When/Then: Testing valid name
        context.viewModel.name = validName
        #expect(context.viewModel.isNameValid)
        #expect(!context.viewModel.showNameError)
        
        // When/Then: Testing invalid name
        context.viewModel.name = invalidName
        #expect(!context.viewModel.isNameValid)
        #expect(context.viewModel.showNameError)
    }
    
    @Test("Validate repository password", tags: ["validation", "repository"])
    func testValidatePassword() async throws {
        // Given: Various passwords
        let context = TestContext()
        let validPassword = MockData.Repository.validPassword
        let invalidPassword = MockData.Repository.invalidPassword
        
        // When/Then: Testing valid password
        context.viewModel.password = validPassword
        #expect(context.viewModel.isPasswordValid)
        #expect(!context.viewModel.showPasswordError)
        
        // When/Then: Testing invalid password
        context.viewModel.password = invalidPassword
        #expect(!context.viewModel.isPasswordValid)
        #expect(context.viewModel.showPasswordError)
    }
    
    // MARK: - Path Selection Tests
    
    @Test("Select repository path", tags: ["path", "selection"])
    func testSelectRepositoryPath() async throws {
        // Given: Valid directory path
        let context = TestContext()
        let selectedPath = MockData.Repository.validRepository.path
        context.mockFileManager.directoryExists[selectedPath.path] = true
        
        // When: Selecting path
        await context.viewModel.selectPath()
        context.viewModel.path = selectedPath
        
        // Then: Path is selected and validated
        #expect(context.viewModel.path == selectedPath)
        #expect(context.viewModel.isPathValid)
    }
}

// MARK: - Mock Implementations

/// Mock implementation of RepositoryCreationService for testing
final class MockRepositoryCreationService: RepositoryCreationServiceProtocol {
    var createCalled = false
    var createResult: Repository?
    var shouldFail = false
    var error: Error?
    
    func createRepository(name: String, path: URL, password: String) async throws -> Repository {
        if shouldFail { throw error! }
        
        createCalled = true
        return createResult!
    }
    
    func validateRepositoryName(_ name: String) async throws -> Bool {
        !name.isEmpty && name.count <= 255
    }
    
    func validateRepositoryPath(_ path: URL) async throws -> Bool {
        path.path.starts(with: "/")
    }
    
    func reset() {
        createCalled = false
        createResult = nil
        shouldFail = false
        error = nil
    }
}

/// Mock implementation of FileManager for testing
final class MockFileManager: FileManager {
    var directoryExists: [String: Bool] = [:]
    var pathExists = true
    var isDirectory = true
    
    override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        if let isDir = isDirectory {
            isDir.pointee = true
        }
        return directoryExists[path] ?? false
    }
    
    func reset() {
        directoryExists.removeAll()
        pathExists = true
        isDirectory = true
    }
}

/// Mock implementation of NotificationCenter for testing
final class MockNotificationCenter: NotificationCenter {
    var postNotificationCalled = false
    var lastNotification: Notification?
    
    override func post(_ notification: Notification) {
        postNotificationCalled = true
        lastNotification = notification
    }
    
    func reset() {
        postNotificationCalled = false
        lastNotification = nil
    }
}
