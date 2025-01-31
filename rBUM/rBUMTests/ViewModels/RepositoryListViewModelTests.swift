import Testing
@testable import rBUM

@MainActor
struct RepositoryListViewModelTests {
    // MARK: - Test Setup
    
    struct TestContext {
        let repositoryStorage: MockRepositoryStorage
        let resticService: MockResticCommandService
        let repositoryCreationService: MockRepositoryCreationService
        let viewModel: RepositoryListViewModel
        
        init() {
            self.repositoryStorage = MockRepositoryStorage()
            self.resticService = MockResticCommandService()
            self.repositoryCreationService = MockRepositoryCreationService()
            self.viewModel = RepositoryListViewModel(
                resticService: resticService,
                repositoryStorage: repositoryStorage,
                repositoryCreationService: repositoryCreationService
            )
        }
    }
    
    // MARK: - Repository Loading Tests
    
    @Test("Load repositories successfully", tags: ["loading", "model"])
    func testLoadRepositoriesSuccess() async throws {
        // Given
        let context = TestContext()
        let repositories = [
            Repository(name: "Test1", path: URL(fileURLWithPath: "/test1")),
            Repository(name: "Test2", path: URL(fileURLWithPath: "/test2"))
        ]
        context.repositoryStorage.listResult = repositories
        
        // When
        await context.viewModel.loadRepositories()
        
        // Then
        #expect(context.viewModel.repositories == repositories)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
    }
    
    @Test("Handle repository loading failure", tags: ["loading", "model", "error"])
    func testLoadRepositoriesFailure() async throws {
        // Given
        let context = TestContext()
        let expectedError = NSError(domain: "test", code: 1)
        context.repositoryStorage.listError = expectedError
        
        // When
        await context.viewModel.loadRepositories()
        
        // Then
        #expect(context.viewModel.repositories.isEmpty)
        #expect(context.viewModel.showError)
        #expect(context.viewModel.error != nil)
    }
    
    // MARK: - Repository Deletion Tests
    
    @Test("Delete repository successfully", tags: ["deletion", "model"])
    func testDeleteRepositorySuccess() async throws {
        // Given
        let context = TestContext()
        let repository = Repository(name: "Test", path: URL(fileURLWithPath: "/test"))
        context.repositoryStorage.listResult = [repository]
        await context.viewModel.loadRepositories()
        
        // When
        await context.viewModel.deleteRepository(repository)
        
        // Then
        #expect(context.viewModel.repositories.isEmpty)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
    }
    
    @Test("Handle repository deletion failure", tags: ["deletion", "model", "error"])
    func testDeleteRepositoryFailure() async throws {
        // Given
        let context = TestContext()
        let repository = Repository(name: "Test", path: URL(fileURLWithPath: "/test"))
        let expectedError = NSError(domain: "test", code: 1)
        context.repositoryStorage.deleteError = expectedError
        context.repositoryStorage.listResult = [repository]
        await context.viewModel.loadRepositories()
        
        // When
        await context.viewModel.deleteRepository(repository)
        
        // Then
        #expect(context.viewModel.repositories.count == 1)
        #expect(context.viewModel.showError)
        #expect(context.viewModel.error != nil)
    }
}

// MARK: - Mock Classes

final class MockRepositoryStorage: RepositoryStorageProtocol {
    var listResult: [Repository] = []
    var listError: Error?
    var deleteError: Error?
    
    func store(_ repository: Repository) throws {
        // Not needed for these tests
    }
    
    func retrieve(forId id: UUID) throws -> Repository? {
        // Not needed for these tests
        return nil
    }
    
    func list() throws -> [Repository] {
        if let error = listError {
            throw error
        }
        return listResult
    }
    
    func delete(forId id: UUID) throws {
        if let error = deleteError {
            throw error
        }
    }
    
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool {
        // Not needed for these tests
        return false
    }
}

final class MockResticCommandService: ResticCommandServiceProtocol {
    func initializeRepository(at path: URL, password: String) async throws {}
    
    func checkRepository(at path: URL, credentials: RepositoryCredentials) async throws {}
    
    func createBackup(
        paths: [URL],
        to repository: Repository,
        credentials: RepositoryCredentials,
        tags: [String]?,
        onProgress: ((BackupProgress) -> Void)?,
        onStatusChange: ((BackupStatus) -> Void)?
    ) async throws {
        // Not needed for these tests
    }
    
    func listSnapshots(in repository: Repository, credentials: RepositoryCredentials) async throws -> [Snapshot] {
        return []
    }
    
    func pruneSnapshots(
        in repository: Repository,
        credentials: RepositoryCredentials,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {}
}

final class MockRepositoryCreationService: RepositoryCreationServiceProtocol {
    func createRepository(name: String, path: URL, password: String) async throws -> Repository {
        return Repository(name: name, path: path)
    }
    
    func importRepository(name: String, path: URL, password: String) async throws -> Repository {
        return Repository(name: name, path: path)
    }
}
