import Testing
@testable import rBUM

/// Tests for RepositoryDetailViewModel functionality
@MainActor
struct RepositoryDetailViewModelTests {
    // MARK: - Test Context
    
    /// Test environment with mocked dependencies
    struct TestContext {
        let viewModel: RepositoryDetailViewModel
        let mockResticService: MockResticService
        let mockBackupService: MockBackupService
        let mockNotificationCenter: MockNotificationCenter
        let mockStorage: MockRepositoryStorage
        
        init() {
            self.mockResticService = MockResticService()
            self.mockBackupService = MockBackupService()
            self.mockNotificationCenter = MockNotificationCenter()
            self.mockStorage = MockRepositoryStorage()
            
            self.viewModel = RepositoryDetailViewModel(
                repository: MockData.Repository.validRepository,
                resticService: mockResticService,
                backupService: mockBackupService,
                notificationCenter: mockNotificationCenter,
                storage: mockStorage
            )
        }
        
        /// Reset all mocks to initial state
        func reset() {
            mockResticService.reset()
            mockBackupService.reset()
            mockNotificationCenter.reset()
            mockStorage.reset()
        }
    }
    
    // MARK: - Repository Status Tests
    
    @Test("Load repository status successfully", tags: ["status", "repository"])
    func testLoadRepositoryStatusSuccess() async throws {
        // Given: Repository with status
        let context = TestContext()
        let status = MockData.Repository.validStatus
        context.mockResticService.repositoryStatus = status
        
        // When: Loading status
        try await context.viewModel.loadRepositoryStatus()
        
        // Then: Status is loaded correctly
        #expect(context.viewModel.status == status)
        #expect(!context.viewModel.isLoading)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
    }
    
    @Test("Handle repository status loading failure", tags: ["status", "repository", "error"])
    func testLoadRepositoryStatusFailure() async throws {
        // Given: Service that will fail
        let context = TestContext()
        context.mockResticService.shouldFail = true
        context.mockResticService.error = MockData.Error.repositoryError
        
        // When: Loading status
        try await context.viewModel.loadRepositoryStatus()
        
        // Then: Error is handled properly
        #expect(context.viewModel.status == nil)
        #expect(!context.viewModel.isLoading)
        #expect(context.viewModel.showError)
        #expect(context.viewModel.error as? MockData.Error == MockData.Error.repositoryError)
    }
    
    // MARK: - Snapshot Tests
    
    @Test("Load snapshots successfully", tags: ["snapshots", "repository"])
    func testLoadSnapshotsSuccess() async throws {
        // Given: Repository with snapshots
        let context = TestContext()
        let snapshots = MockData.Repository.validSnapshots
        context.mockResticService.snapshots = snapshots
        
        // When: Loading snapshots
        try await context.viewModel.loadSnapshots()
        
        // Then: Snapshots are loaded correctly
        #expect(context.viewModel.snapshots == snapshots)
        #expect(!context.viewModel.isLoading)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
    }
    
    @Test("Handle snapshots failure", tags: ["snapshots", "repository", "error"])
    func testLoadSnapshotsFailure() async throws {
        // Given: Snapshots will fail
        let context = TestContext()
        context.mockResticService.shouldFail = true
        context.mockResticService.error = MockData.Error.snapshotListError
        
        // When: Loading snapshots
        try await context.viewModel.loadSnapshots()
        
        // Then: Error is handled correctly
        #expect(context.viewModel.snapshots == [])
        #expect(!context.viewModel.isLoading)
        #expect(context.viewModel.showError)
        #expect(context.viewModel.error as? MockData.Error == MockData.Error.snapshotListError)
    }
    
    // MARK: - Backup Tests
    
    @Test("Start backup successfully", tags: ["backup", "repository"])
    func testStartBackupSuccess() async throws {
        // Given: Repository ready for backup
        let context = TestContext()
        let backup = MockData.Backup.validBackup
        context.mockBackupService.backupResult = backup
        
        // When: Starting backup
        try await context.viewModel.startBackup()
        
        // Then: Backup starts without error
        #expect(context.mockBackupService.startBackupCalled)
        #expect(!context.viewModel.isLoading)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
        #expect(context.mockNotificationCenter.postNotificationCalled)
    }
    
    @Test("Handle backup start failure", tags: ["backup", "repository", "error"])
    func testStartBackupFailure() async throws {
        // Given: Backup will fail
        let context = TestContext()
        context.mockBackupService.shouldFail = true
        context.mockBackupService.error = MockData.Error.backupError
        
        // When: Starting backup
        try await context.viewModel.startBackup()
        
        // Then: Error is handled properly
        #expect(context.mockBackupService.startBackupCalled)
        #expect(!context.viewModel.isLoading)
        #expect(context.viewModel.showError)
        #expect(context.viewModel.error as? MockData.Error == MockData.Error.backupError)
    }
    
    // MARK: - Repository Update Tests
    
    @Test("Update repository settings successfully", tags: ["settings", "repository"])
    func testUpdateRepositorySettingsSuccess() async throws {
        // Given: Repository with new settings
        let context = TestContext()
        let newSettings = MockData.Repository.validSettings
        
        // When: Updating settings
        try await context.viewModel.updateSettings(newSettings)
        
        // Then: Settings are updated without error
        #expect(context.viewModel.repository.settings == newSettings)
        #expect(!context.viewModel.isLoading)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
        #expect(context.mockStorage.updateCalled)
    }
    
    @Test("Update repository successfully", tags: ["update", "repository"])
    func testUpdateRepositorySuccess() async throws {
        // Given: Updated repository data
        let context = TestContext()
        let updatedRepo = MockData.Repository.validRepository
        context.mockStorage.repositoryToReturn = updatedRepo
        
        // When: Updating repository
        try await context.viewModel.updateRepository(name: updatedRepo.name)
        
        // Then: Repository is updated correctly
        #expect(context.mockStorage.updateCalled)
        #expect(context.viewModel.repository.name == updatedRepo.name)
        #expect(!context.viewModel.isLoading)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.error == nil)
        #expect(context.mockNotificationCenter.postCalled)
        #expect(context.mockNotificationCenter.lastNotification?.name == .repositoryUpdated)
    }
    
    @Test("Handle repository update failure", tags: ["update", "repository", "error"])
    func testUpdateRepositoryFailure() async throws {
        // Given: Repository update will fail
        let context = TestContext()
        context.mockStorage.shouldFail = true
        context.mockStorage.error = MockData.Error.repositoryUpdateError
        
        // When: Updating repository
        try await context.viewModel.updateRepository(name: "New Name")
        
        // Then: Error is handled correctly
        #expect(context.viewModel.repository.name != "New Name")
        #expect(!context.viewModel.isLoading)
        #expect(context.viewModel.showError)
        #expect(context.viewModel.error as? MockData.Error == MockData.Error.repositoryUpdateError)
    }
}

// MARK: - Mock Implementations

/// Mock implementation of ResticService for testing
final class MockResticService: ResticServiceProtocol {
    var repositoryStatus: RepositoryStatus?
    var snapshots: [Snapshot] = []
    var shouldFail = false
    var error: Error?
    
    func getRepositoryStatus(for repository: Repository) async throws -> RepositoryStatus {
        if shouldFail { throw error ?? MockData.Error.repositoryError }
        return repositoryStatus ?? MockData.Repository.validStatus
    }
    
    func getSnapshots(for repository: Repository) async throws -> [Snapshot] {
        if shouldFail { throw error ?? MockData.Error.snapshotListError }
        return snapshots
    }
    
    func reset() {
        repositoryStatus = nil
        snapshots = []
        shouldFail = false
        error = nil
    }
}

/// Mock implementation of BackupService for testing
final class MockBackupService: BackupServiceProtocol {
    var backupResult: Backup?
    var startBackupCalled = false
    var shouldFail = false
    var error: Error?
    
    func startBackup(for repository: Repository) async throws -> Backup {
        if shouldFail { throw error ?? MockData.Error.backupError }
        startBackupCalled = true
        return backupResult ?? MockData.Backup.validBackup
    }
    
    func reset() {
        backupResult = nil
        startBackupCalled = false
        shouldFail = false
        error = nil
    }
}

/// Mock implementation of RepositoryStorage for testing
final class MockRepositoryStorage: RepositoryStorageProtocol {
    var repositoryToReturn: Repository?
    var updateCalled = false
    var shouldFail = false
    var error: Error?
    
    func update(_ repository: Repository) async throws -> Repository {
        if shouldFail { throw error ?? MockData.Error.repositoryUpdateError }
        updateCalled = true
        return repositoryToReturn ?? repository
    }
    
    func reset() {
        repositoryToReturn = nil
        updateCalled = false
        shouldFail = false
        error = nil
    }
}

/// Mock implementation of NotificationCenter for testing
final class MockNotificationCenter: NotificationCenter {
    var postCalled = false
    var lastNotification: Notification?
    
    override func post(_ notification: Notification) {
        postCalled = true
        lastNotification = notification
    }
    
    func reset() {
        postCalled = false
        lastNotification = nil
    }
}
