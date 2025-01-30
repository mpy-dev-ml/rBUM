//
//  RepositoryListViewModelTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
@testable import rBUM

@MainActor
final class RepositoryListViewModelTests: XCTestCase {
    fileprivate var viewModel: RepositoryListViewModel!
    fileprivate var mockStorage: MockRepositoryStorage!
    fileprivate var testRepositories: [Repository]!
    
    override func setUp() async throws {
        mockStorage = MockRepositoryStorage()
        viewModel = RepositoryListViewModel(repositoryStorage: mockStorage)
        
        testRepositories = [
            Repository(name: "Test 1", path: URL(filePath: "/test/1")),
            Repository(name: "Test 2", path: URL(filePath: "/test/2"))
        ]
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockStorage = nil
        testRepositories = nil
    }
    
    func testLoadRepositories() throws {
        // Given
        mockStorage.listResult = testRepositories
        
        // When
        viewModel.loadRepositories()
        
        // Then
        XCTAssertEqual(viewModel.repositories.count, 2)
        XCTAssertEqual(viewModel.repositories[0].name, "Test 1")
        XCTAssertEqual(viewModel.repositories[1].name, "Test 2")
    }
    
    func testLoadRepositoriesError() throws {
        // Given
        let expectedError = NSError(domain: "test", code: 1)
        mockStorage.listError = expectedError
        
        // When
        viewModel.loadRepositories()
        
        // Then
        XCTAssertTrue(viewModel.repositories.isEmpty)
        XCTAssertEqual(viewModel.error as NSError?, expectedError)
        XCTAssertTrue(viewModel.showError)
    }
    
    func testHandleNewRepository() throws {
        // Given
        let repository = testRepositories[0]
        
        // When
        viewModel.handleNewRepository(repository)
        
        // Then
        XCTAssertEqual(viewModel.repositories.count, 1)
        XCTAssertEqual(viewModel.repositories[0].id, repository.id)
        
        // When adding same repository again
        viewModel.handleNewRepository(repository)
        
        // Then should not duplicate
        XCTAssertEqual(viewModel.repositories.count, 1)
    }
    
    func testDeleteRepository() throws {
        // Given
        mockStorage.listResult = testRepositories
        viewModel.loadRepositories()
        
        // When
        viewModel.deleteRepository(testRepositories[0])
        
        // Then
        XCTAssertEqual(viewModel.repositories.count, 1)
        XCTAssertEqual(viewModel.repositories[0].id, testRepositories[1].id)
        XCTAssertTrue(mockStorage.deleteCalled)
        XCTAssertEqual(mockStorage.deleteId, testRepositories[0].id)
    }
    
    func testDeleteRepositoryError() throws {
        // Given
        mockStorage.listResult = testRepositories
        viewModel.loadRepositories()
        
        let expectedError = NSError(domain: "test", code: 1)
        mockStorage.deleteError = expectedError
        
        // When
        viewModel.deleteRepository(testRepositories[0])
        
        // Then
        XCTAssertEqual(viewModel.repositories.count, 2)
        XCTAssertEqual(viewModel.error as NSError?, expectedError)
        XCTAssertTrue(viewModel.showError)
    }
}

// MARK: - Mocks

private final class MockRepositoryStorage: RepositoryStorageProtocol {
    var listResult: [Repository]?
    var listError: Error?
    var deleteError: Error?
    var deleteCalled = false
    var deleteId: UUID?
    
    func store(_ repository: Repository) throws {}
    
    func retrieve(forId id: UUID) throws -> Repository? {
        return nil
    }
    
    func list() throws -> [Repository] {
        if let error = listError {
            throw error
        }
        return listResult ?? []
    }
    
    func delete(forId id: UUID) throws {
        deleteCalled = true
        deleteId = id
        if let error = deleteError {
            throw error
        }
    }
    
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool {
        return false
    }
}
