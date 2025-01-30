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
    static let repositoryStorage = MockRepositoryStorage()
    static let resticService = MockResticCommandService()
    static let repositoryCreationService = MockRepositoryCreationService()
    var sut: RepositoryListViewModel!
    
    override class func setUp() {
        super.setUp()
    }
    
    override class func tearDown() {
        super.tearDown()
    }
    
    override func setUp() async throws {
        sut = RepositoryListViewModel(
            resticService: Self.resticService,
            repositoryStorage: Self.repositoryStorage,
            repositoryCreationService: Self.repositoryCreationService
        )
    }
    
    override func tearDown() async throws {
        sut = nil
    }
    
    func test_loadRepositories_success() async throws {
        // Given
        let repositories = [
            Repository(name: "Test1", path: URL(fileURLWithPath: "/test1")),
            Repository(name: "Test2", path: URL(fileURLWithPath: "/test2"))
        ]
        Self.repositoryStorage.listResult = repositories
        
        // When
        await sut.loadRepositories()
        
        // Then
        XCTAssertEqual(sut.repositories, repositories)
        XCTAssertFalse(sut.showError)
        XCTAssertNil(sut.error)
    }
    
    func test_loadRepositories_failure() async throws {
        // Given
        let expectedError = NSError(domain: "test", code: 1)
        Self.repositoryStorage.listError = expectedError
        
        // When
        await sut.loadRepositories()
        
        // Then
        XCTAssertTrue(sut.repositories.isEmpty)
        XCTAssertTrue(sut.showError)
        XCTAssertNotNil(sut.error)
    }
    
    func test_deleteRepository_success() async throws {
        // Given
        let repository = Repository(name: "Test", path: URL(fileURLWithPath: "/test"))
        Self.repositoryStorage.listResult = [repository]
        await sut.loadRepositories()
        
        // When
        await sut.deleteRepository(repository)
        
        // Then
        XCTAssertTrue(sut.repositories.isEmpty)
        XCTAssertFalse(sut.showError)
        XCTAssertNil(sut.error)
    }
    
    func test_deleteRepository_failure() async throws {
        // Given
        let repository = Repository(name: "Test", path: URL(fileURLWithPath: "/test"))
        let expectedError = NSError(domain: "test", code: 1)
        Self.repositoryStorage.deleteError = expectedError
        Self.repositoryStorage.listResult = [repository]
        await sut.loadRepositories()
        
        // When
        await sut.deleteRepository(repository)
        
        // Then
        XCTAssertEqual(sut.repositories.count, 1)
        XCTAssertTrue(sut.showError)
        XCTAssertNotNil(sut.error)
    }
}

// MARK: - Mock Classes

final class MockRepositoryStorage: RepositoryStorageProtocol {
    func store(_ repository: rBUM.Repository) throws {
        <#code#>
    }
    
    func retrieve(forId id: UUID) throws -> rBUM.Repository? {
        <#code#>
    }
    
    func list() throws -> [rBUM.Repository] {
        <#code#>
    }
    
    func delete(forId id: UUID) throws {
        <#code#>
    }
    
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool {
        <#code#>
    }
    
    var listResult: [Repository] = []
    var listError: Error?
    var deleteError: Error?
    
    func list() async throws -> [Repository] {
        if let error = listError {
            throw error
        }
        return listResult
    }
    
    func delete(forId id: UUID) async throws {
        if let error = deleteError {
            throw error
        }
    }
    
    func store(_ repository: Repository) async throws {
        // Not needed for these tests
    }
    
    func retrieve(forId id: UUID) async throws -> Repository? {
        // Not needed for these tests
        return nil
    }
    
    func exists(atPath path: URL, excludingId: UUID?) async throws -> Bool {
        // Not needed for these tests
        return false
    }
}

final class MockResticCommandService: ResticCommandServiceProtocol {
    func createBackup(paths: [URL], to repository: rBUM.Repository, credentials: rBUM.RepositoryCredentials, tags: [String]?, onProgress: ((rBUM.BackupProgress) -> Void)?, onStatusChange: ((rBUM.BackupStatus) -> Void)?) async throws {
        <#code#>
    }
    
    func initializeRepository(at path: URL, password: String) async throws {}
    
    func checkRepository(at path: URL, credentials: RepositoryCredentials) async throws {}
    
    func createBackup(paths: [URL], to repository: Repository, credentials: RepositoryCredentials, tags: [String]?) async throws {}
    
    func listSnapshots(in repository: Repository, credentials: RepositoryCredentials) async throws -> [Snapshot] {
        return []
    }
    
    func pruneSnapshots(in repository: Repository, credentials: RepositoryCredentials, keepLast: Int?, keepDaily: Int?, keepWeekly: Int?, keepMonthly: Int?, keepYearly: Int?) async throws {}
}

final class MockRepositoryCreationService: RepositoryCreationServiceProtocol {
    func createRepository(name: String, path: URL, password: String) async throws -> Repository {
        return Repository(name: name, path: path)
    }
    
    func importRepository(name: String, path: URL, password: String) async throws -> Repository {
        return Repository(name: name, path: path)
    }
}
