import Core
@testable import rBUM
import XCTest

@MainActor
final class FileSearchViewModelTests: XCTestCase {
    // MARK: - Properties
    
    private var sut: FileSearchViewModel!
    private var mockFileSearchService: MockFileSearchService!
    private var mockRestoreService: MockRestoreService!
    private var mockRepositoryStorage: MockRepositoryStorage!
    private var logger: LoggerProtocol!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        super.setUp()
        mockFileSearchService = MockFileSearchService()
        mockRestoreService = MockRestoreService()
        mockRepositoryStorage = MockRepositoryStorage()
        logger = TestUtilities.createLogger()
        sut = FileSearchViewModel(
            fileSearchService: mockFileSearchService,
            restoreService: mockRestoreService,
            repositoryStorage: mockRepositoryStorage,
            logger: logger
        )
    }
    
    override func tearDown() {
        sut = nil
        mockFileSearchService = nil
        mockRestoreService = nil
        mockRepositoryStorage = nil
        logger = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testInit_LoadsRepositories() async throws {
        // Given
        let expectedRepo = TestRepositoryUtilities.createTestRepository()
        mockRepositoryStorage.repositories = [expectedRepo]
        
        // When
        let sut = FileSearchViewModel(
            fileSearchService: mockFileSearchService,
            restoreService: mockRestoreService,
            repositoryStorage: mockRepositoryStorage,
            logger: logger
        )
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(sut.repositories.count, 1)
        XCTAssertEqual(sut.repositories[0].url, expectedRepo.url)
        XCTAssertEqual(sut.selectedRepository?.url, expectedRepo.url)
    }
    
    func testPerformSearch_WithValidPattern_UpdatesResults() async throws {
        // Given
        let expectedRepo = TestRepositoryUtilities.createTestRepository()
        sut.selectedRepository = expectedRepo
        sut.searchPattern = "test.txt"
        
        let expectedMatch = FileMatch(
            path: "/test.txt",
            size: 100,
            modTime: Date(),
            hash: "abc123"
        )
        mockFileSearchService.searchResults = [expectedMatch]
        
        // When
        await sut.performSearch()
        
        // Then
        XCTAssertEqual(sut.searchResults.count, 1)
        XCTAssertEqual(sut.searchResults[0].path, expectedMatch.path)
        XCTAssertFalse(sut.isSearching)
        XCTAssertNil(sut.error)
    }
    
    func testPerformSearch_WithNoRepository_DoesNothing() async {
        // Given
        sut.selectedRepository = nil
        sut.searchPattern = "test.txt"
        
        // When
        await sut.performSearch()
        
        // Then
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertFalse(sut.isSearching)
        XCTAssertNil(sut.error)
    }
    
    func testPerformSearch_WhenServiceFails_SetsError() async {
        // Given
        let expectedRepo = TestRepositoryUtilities.createTestRepository()
        sut.selectedRepository = expectedRepo
        sut.searchPattern = "test.txt"
        
        let expectedError = FileSearchError.invalidPattern
        mockFileSearchService.searchError = expectedError
        
        // When
        await sut.performSearch()
        
        // Then
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertFalse(sut.isSearching)
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(sut.error as? FileSearchError, expectedError)
    }
}

// MARK: - Mocks

private class MockFileSearchService: FileSearchServiceProtocol {
    var searchResults: [FileMatch] = []
    var searchError: Error?
    var fileVersions: [FileVersion] = []
    var fileVersionsError: Error?
    
    func searchFile(pattern: String, in repository: Repository) async throws -> [FileMatch] {
        if let error = searchError {
            throw error
        }
        return searchResults
    }
    
    func getFileVersions(path: String, in repository: Repository) async throws -> [FileVersion] {
        if let error = fileVersionsError {
            throw error
        }
        return fileVersions
    }
}

private class MockRestoreService: RestoreServiceProtocol {
    var restoreError: Error?
    var snapshotsResult: [ResticSnapshot] = []
    var snapshotsError: Error?
    
    func restore(
        snapshot: ResticSnapshot,
        from repository: Repository,
        paths: [String],
        to target: String
    ) async throws {
        if let error = restoreError {
            throw error
        }
    }
    
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        if let error = snapshotsError {
            throw error
        }
        return snapshotsResult
    }
}

private class MockRepositoryStorage: RepositoryStorageProtocol {
    var repositories: [Repository] = []
    var loadError: Error?
    var saveError: Error?
    var deleteError: Error?
    
    func loadRepositories() async throws -> [Repository] {
        if let error = loadError {
            throw error
        }
        return repositories
    }
    
    func saveRepository(_ repository: Repository) async throws {
        if let error = saveError {
            throw error
        }
        repositories.append(repository)
    }
    
    func deleteRepository(_ repository: Repository) async throws {
        if let error = deleteError {
            throw error
        }
        repositories.removeAll { $0.url == repository.url }
    }
}
