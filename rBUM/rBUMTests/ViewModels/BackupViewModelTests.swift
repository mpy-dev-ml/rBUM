import Testing
@testable import rBUM

@MainActor
struct BackupViewModelTests {
    // MARK: - Test Setup
    
    struct TestContext {
        let resticService: TestMocks.MockResticCommandService
        let credentialsManager: TestMocks.MockCredentialsManager
        let repository: Repository
        let viewModel: BackupViewModel
        
        init() {
            self.resticService = TestMocks.MockResticCommandService()
            self.credentialsManager = TestMocks.MockCredentialsManager()
            self.repository = Repository(name: "Test Repo", path: URL(fileURLWithPath: "/test/repo"))
            self.viewModel = BackupViewModel(
                repository: repository,
                resticService: resticService,
                credentialsManager: credentialsManager
            )
        }
    }
    
    // MARK: - Basic Tests
    
    @Test("Verify initial state of backup view model", tags: ["basic", "model"])
    func testInitialState() async throws {
        // Given
        let context = TestContext()
        
        // Then
        #expect(context.viewModel.state == .idle)
        #expect(context.viewModel.selectedPaths.isEmpty)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.currentStatus == nil)
        #expect(context.viewModel.currentProgress == nil)
        #expect(context.viewModel.progressMessage == "Ready to start backup")
        #expect(context.viewModel.progressPercentage == 0)
    }
    
    // MARK: - Backup Tests
    
    @Test("Handle backup progress updates", tags: ["model", "backup"])
    func testBackupProgress() async throws {
        // Given
        let context = TestContext()
        let paths = [URL(fileURLWithPath: "/test/file1")]
        context.viewModel.selectedPaths = paths
        
        let credentials = context.credentialsManager.createCredentials(
            id: context.repository.id,
            path: context.repository.path.path,
            password: "testPassword"
        )
        try await context.credentialsManager.store(credentials)
        
        // When
        await context.viewModel.startBackup()
        
        // Then
        #expect(context.viewModel.currentProgress != nil)
        
        if case .inProgress(let progress) = context.viewModel.state {
            #expect(progress.totalFiles == 10)
            #expect(progress.processedFiles == 5)
            #expect(progress.totalBytes == 1024)
            #expect(progress.processedBytes == 512)
            #expect(progress.currentFile == "/test/file.txt")
            #expect(progress.estimatedSecondsRemaining == 10)
        } else {
            #expect(false, "Expected .inProgress state")
        }
        
        if let status = context.viewModel.currentStatus {
            #expect(status == .completed)
        } else {
            #expect(false, "Expected status to be .completed")
        }
        
        // Verify final state
        #expect(context.viewModel.state == .completed)
        #expect(context.viewModel.progressPercentage == 100)
        #expect(context.viewModel.progressMessage == "Backup completed successfully")
    }
    
    @Test("Handle backup failure", tags: ["model", "backup", "error"])
    func testBackupFailure() async throws {
        // Given
        let context = TestContext()
        let paths = [URL(fileURLWithPath: "/test/file1")]
        context.viewModel.selectedPaths = paths
        
        let credentials = context.credentialsManager.createCredentials(
            id: context.repository.id,
            path: context.repository.path.path,
            password: "testPassword"
        )
        try await context.credentialsManager.store(credentials)
        
        let testError = ResticError.backupFailed("Test error")
        context.resticService.backupError = testError
        
        // When
        await context.viewModel.startBackup()
        
        // Then
        if case let .failed(error) = context.viewModel.state,
           let resticError = error as? ResticError {
            #expect(resticError == testError)
        } else {
            #expect(false, "Expected .failed state with ResticError")
        }
        
        #expect(context.viewModel.showError)
        #expect(context.viewModel.progressPercentage == 0)
        #expect(context.viewModel.progressMessage == "Backup failed: \(testError.localizedDescription)")
    }
    
    // MARK: - Reset Tests
    
    @Test("Reset backup view model state", tags: ["model", "reset"])
    func testReset() async throws {
        // Given
        let context = TestContext()
        context.viewModel.selectedPaths = [URL(fileURLWithPath: "/test/file1")]
        context.viewModel.showError = true
        
        // When
        await context.viewModel.reset()
        
        // Then
        #expect(context.viewModel.state == .idle)
        #expect(context.viewModel.selectedPaths.isEmpty)
        #expect(!context.viewModel.showError)
        #expect(context.viewModel.currentStatus == nil)
        #expect(context.viewModel.currentProgress == nil)
        #expect(context.viewModel.progressMessage == "Ready to start backup")
        #expect(context.viewModel.progressPercentage == 0)
    }
}
