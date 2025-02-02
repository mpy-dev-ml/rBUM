//
//  RepositoryCreationViewModelTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
import Foundation
@testable import rBUM
import Testing
import TestMocksModule

/// Tests for RepositoryCreationViewModel functionality
@MainActor
struct RepositoryCreationViewModelTests {
    // MARK: - Test Context
    
    /// Test environment with mocked dependencies
    private struct TestContext {
        let repositoryManager: TestMocks.MockRepositoryManager
        let fileManager: TestMocks.MockFileManager
        let notificationCenter: TestMocks.MockNotificationCenter
        let logger: TestMocks.MockLogger
        
        init() {
            repositoryManager = TestMocks.MockRepositoryManager()
            fileManager = TestMocks.MockFileManager()
            notificationCenter = TestMocks.MockNotificationCenter()
            logger = TestMocks.MockLogger()
        }
        
        func createViewModel() -> RepositoryCreationViewModel {
            RepositoryCreationViewModel(
                repositoryManager: repositoryManager,
                fileManager: fileManager,
                notificationCenter: notificationCenter,
                logger: logger
            )
        }
        
        func reset() {
            repositoryManager.reset()
            fileManager.reset()
            notificationCenter.reset()
            logger.reset()
        }
    }
    
    // MARK: - Tests
    
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating view model
        let viewModel = context.createViewModel()
        
        // Then: View model is properly configured
        XCTAssertEqual(viewModel.name, "")
        XCTAssertEqual(viewModel.path, "")
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.error)
    }
    
    func testRepositoryCreation() async throws {
        // Given: Test context and view model
        let context = TestContext()
        let viewModel = context.createViewModel()
        
        // When: Creating repository
        viewModel.name = "Test Repository"
        viewModel.path = "/test/path"
        await viewModel.createRepository()
        
        // Then: Repository is created
        XCTAssertTrue(context.repositoryManager.createRepositoryCalled)
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.error)
    }
    
    func testValidation() async throws {
        // Given: Test context and view model
        let context = TestContext()
        let viewModel = context.createViewModel()
        
        // Test empty name
        viewModel.name = ""
        viewModel.path = "/test/path"
        XCTAssertFalse(viewModel.isValid)
        
        // Test empty path
        viewModel.name = "Test Repository"
        viewModel.path = ""
        XCTAssertFalse(viewModel.isValid)
        
        // Test valid input
        viewModel.name = "Test Repository"
        viewModel.path = "/test/path"
        XCTAssertTrue(viewModel.isValid)
    }
    
    func testErrorHandling() async throws {
        // Given: Test context and view model
        let context = TestContext()
        let viewModel = context.createViewModel()
        
        // Test error scenarios
        for errorCase in MockData.Error.repositoryErrors {
            // Setup error condition
            context.repositoryManager.simulateError = errorCase
            
            // When: Creating repository
            viewModel.name = "Test Repository"
            viewModel.path = "/test/path"
            await viewModel.createRepository()
            
            // Then: Error is handled correctly
            XCTAssertFalse(viewModel.isCreating)
            XCTAssertTrue(viewModel.showError)
            XCTAssertNotNil(viewModel.error)
            if let error = viewModel.error as? RepositoryError {
                XCTAssertEqual(error, errorCase)
            }
            
            context.reset()
        }
    }
}
