/// Tests for RepositoryListViewModel functionality
@MainActor
struct RepositoryListViewModelTests {
    // MARK: - Test Context
    
    /// Test environment with mocked dependencies
    struct TestContext {
        let repositoryStorage: MockRepositoryStorage      // Mocked storage
        let resticService: MockResticCommandService      // Mocked Restic commands
        let repositoryCreationService: MockRepositoryCreationService  // Mocked creation
        let viewModel: RepositoryListViewModel           // System under test
        
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
        
        /// Reset all mocks to initial state
        func reset() {
            repositoryStorage.reset()
            resticService.reset()
            repositoryCreationService.reset()
        }
    }
    
    // MARK: - Repository Loading Tests
    
    @Test("Load repositories successfully", tags: ["loading", "model"])
    func testLoadRepositoriesSuccess() async throws {
        // Given: Storage with test repositories
        let context = TestContext()
        context.repositoryStorage.listResult = MockData.Repository.validRepositories
        
        // When: Loading repositories
        await context.viewModel.loadRepositories()
        
        // Then: Repositories are loaded without error
        #expect(context.viewModel.repositories == MockData.Repository.validRepositories)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
    }
    
    @Test("Handle repository loading failure", tags: ["loading", "model", "error"])
    func testLoadRepositoriesFailure() async throws {
        // Given: Storage that will fail
        let context = TestContext()
        context.repositoryStorage.shouldFail = true
        context.repositoryStorage.error = MockData.Error.storageError
        
        // When: Loading repositories
        await context.viewModel.loadRepositories()
        
        // Then: Error is handled properly
        #expect(context.viewModel.repositories.isEmpty)
        #expect(context.viewModel.showError)
        #expect(context.viewModel.error as? MockData.Error == MockData.Error.storageError)
    }
    
    // MARK: - Repository Creation Tests
    
    @Test("Create repository successfully", tags: ["create", "model"])
    func testCreateRepositorySuccess() async throws {
        // Given: Creation service with mock data
        let context = TestContext()
        let repository = MockData.Repository.validRepository
        context.repositoryCreationService.createResult = repository
        
        // When: Creating repository
        await context.viewModel.createRepository(
            name: repository.name,
            path: repository.path,
            password: MockData.Repository.validPassword
        )
        
        // Then: Repository is created without error
        #expect(context.viewModel.repositories.contains(repository))
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
        #expect(context.repositoryCreationService.createCalled)
    }
    
    @Test("Handle repository creation failure", tags: ["creation", "model", "error"])
    func testCreateRepositoryFailure() async throws {
        // Given: Creation service that will fail
        let context = TestContext()
        let repository = MockData.Repository.validRepository
        let credentials = MockData.Credentials.validCredentials
        context.repositoryCreationService.createError = MockData.Errors.fileOperationError
        
        // When: Creating a new repository
        await context.viewModel.createRepository(at: repository.path, name: repository.name, credentials: credentials)
        
        // Then: Error is shown and repository is not created
        #expect(context.repositoryCreationService.createCalled)
        #expect(context.viewModel.showError)
        #expect(context.viewModel.error as? NSError == MockData.Errors.fileOperationError)
    }
    
    // MARK: - Repository Deletion Tests
    
    @Test("Delete repository successfully", tags: ["delete", "model"])
    func testDeleteRepositorySuccess() async throws {
        // Given: Storage with test repository
        let context = TestContext()
        let repository = MockData.Repository.validRepository
        context.repositoryStorage.listResult = [repository]
        await context.viewModel.loadRepositories()
        
        // When: Deleting repository
        await context.viewModel.deleteRepository(repository)
        
        // Then: Repository is deleted without error
        #expect(!context.viewModel.repositories.contains(repository))
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
        #expect(context.repositoryStorage.deleteCalled)
    }
    
    @Test("Handle repository deletion failure", tags: ["deletion", "model", "error"])
    func testDeleteRepositoryFailure() async throws {
        // Given: Storage that will fail
        let context = TestContext()
        let repository = MockData.Repository.validRepository
        context.repositoryStorage.listResult = [repository]
        context.repositoryStorage.deleteError = MockData.Errors.fileOperationError
        await context.viewModel.loadRepositories()
        
        // When: Deleting repository
        await context.viewModel.deleteRepository(repository)
        
        // Then: Error is shown and repository is not deleted
        #expect(context.repositoryStorage.deleteCalled)
        #expect(!context.viewModel.repositories.isEmpty)
        #expect(context.viewModel.showError)
        #expect(context.viewModel.error as? NSError == MockData.Errors.fileOperationError)
    }
}

// MARK: - Mock Classes

final class MockRepositoryStorage: RepositoryStorageProtocol {
    var listResult: [Repository] = []
    var listError: Error?
    var deleteError: Error?
    var deleteCalled = false
    var lastDeletedId: UUID?
    var shouldFail = false
    var error: MockData.Error?
    
    func store(_ repository: Repository) throws {
        // Not needed for these tests
    }
    
    func retrieve(forId id: UUID) throws -> Repository? {
        // Not needed for these tests
        return nil
    }
    
    func list() throws -> [Repository] {
        if shouldFail {
            throw error ?? MockData.Error.storageError
        }
        if let error = listError {
            throw error
        }
        return listResult
    }
    
    func delete(forId id: UUID) throws {
        deleteCalled = true
        lastDeletedId = id
        if let error = deleteError {
            throw error
        }
    }
    
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool {
        // Not needed for these tests
        return false
    }
    
    func reset() {
        deleteCalled = false
        lastDeletedId = nil
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
    
    func reset() {
        // Not needed for these tests
    }
}

final class MockRepositoryCreationService: RepositoryCreationServiceProtocol {
    var createResult: Repository?
    var createError: Error?
    var createCalled = false
    var lastPath: URL?
    var lastCredentials: RepositoryCredentials?
    
    func createRepository(name: String, path: URL, password: String) async throws -> Repository {
        createCalled = true
        lastPath = path
        lastCredentials = RepositoryCredentials(password: password)
        if let error = createError {
            throw error
        }
        return createResult ?? Repository(name: name, path: path)
    }
    
    func importRepository(name: String, path: URL, password: String) async throws -> Repository {
        return Repository(name: name, path: path)
    }
    
    func reset() {
        createCalled = false
        lastPath = nil
        lastCredentials = nil
    }
}
