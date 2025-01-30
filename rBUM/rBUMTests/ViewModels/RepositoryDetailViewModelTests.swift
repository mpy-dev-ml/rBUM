//
//  RepositoryDetailViewModelTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
@testable import rBUM

@MainActor
final class RepositoryDetailViewModelTests: XCTestCase {
    fileprivate var viewModel: RepositoryDetailViewModel!
    fileprivate var mockResticService: MockResticCommandService!
    fileprivate var testRepository: Repository!
    
    override func setUp() async throws {
        testRepository = Repository(
            name: "Test Repo",
            path: URL(filePath: "/test/path")
        )
        mockResticService = MockResticCommandService()
        viewModel = RepositoryDetailViewModel(
            repository: testRepository,
            resticService: mockResticService
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockResticService = nil
        testRepository = nil
    }
    
    func testCheckRepository() async throws {
        // Given
        mockResticService.checkResult = true
        
        // When
        await viewModel.checkRepository()
        
        // Then
        XCTAssertTrue(mockResticService.checkCalled)
        XCTAssertNotNil(viewModel.lastCheck)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.showError)
    }
    
    func testCheckRepositoryFailure() async throws {
        // Given
        mockResticService.checkResult = false
        
        // When
        await viewModel.checkRepository()
        
        // Then
        XCTAssertTrue(mockResticService.checkCalled)
        XCTAssertNil(viewModel.lastCheck)
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.showError)
    }
    
    func testStatusColor() async throws {
        // Given no last check
        XCTAssertEqual(viewModel.statusColor, .secondary)
        
        // Given recent check with no error
        viewModel.lastCheck = Date()
        viewModel.error = nil
        XCTAssertEqual(viewModel.statusColor, .green)
        
        // Given old check with no error
        viewModel.lastCheck = Date().addingTimeInterval(-86401) // More than a day ago
        viewModel.error = nil
        XCTAssertEqual(viewModel.statusColor, .red)
        
        // Given recent check with error
        viewModel.lastCheck = Date()
        viewModel.error = RepositoryCreationError.invalidRepository
        XCTAssertEqual(viewModel.statusColor, .red)
    }
    
    func testFormattedLastCheck() {
        // Given no last check
        XCTAssertEqual(viewModel.formattedLastCheck, "Never")
        
        // Given recent check
        let now = Date()
        viewModel.lastCheck = now
        XCTAssertEqual(viewModel.formattedLastCheck, "now")
    }
}

// MARK: - Mocks

private final class MockResticCommandService: ResticCommandServiceProtocol {
    var checkResult = false
    var checkCalled = false
    
    func initializeRepository(_ repository: Repository, password: String) async throws {}
    
    func checkRepository(_ repository: Repository) async throws -> Bool {
        checkCalled = true
        if !checkResult {
            throw ResticError.invalidRepository
        }
        return true
    }
    
    func createBackup(for repository: Repository, paths: [String]) async throws {}
}
