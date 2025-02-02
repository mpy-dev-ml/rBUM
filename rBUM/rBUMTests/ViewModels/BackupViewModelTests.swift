import Foundation
@testable import rBUM
import Testing
import TestMocksModule

/// Tests for BackupViewModel functionality
@MainActor
struct BackupViewModelTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    private struct TestContext {
        let backupManager: TestMocks.MockBackupManager
        let configManager: TestMocks.MockConfigurationManager
        let notificationCenter: TestMocks.MockNotificationCenter
        let dateProvider: TestMocks.MockDateProvider
        let progressTracker: TestMocks.MockProgressTracker
        let logger: TestMocks.MockLogger
        
        init() {
            backupManager = TestMocks.MockBackupManager()
            configManager = TestMocks.MockConfigurationManager()
            notificationCenter = TestMocks.MockNotificationCenter()
            dateProvider = TestMocks.MockDateProvider()
            progressTracker = TestMocks.MockProgressTracker()
            logger = TestMocks.MockLogger()
        }
        
        func createViewModel() -> BackupViewModel {
            BackupViewModel(
                backupManager: backupManager,
                configManager: configManager,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider,
                progressTracker: progressTracker,
                logger: logger
            )
        }
        
        mutating func reset() {
            backupManager.reset()
            configManager.reset()
            notificationCenter.reset()
            dateProvider.reset()
            progressTracker.reset()
            logger.reset()
        }
    }
    
    // MARK: - Tests
    
    @Test("View model initializes with empty state", [.init, .viewModel])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating view model
        let viewModel = context.createViewModel()
        
        // Then: View model is properly configured
        #expect(viewModel.backups.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(!viewModel.showError)
        #expect(viewModel.error == nil)
    }
    
    @Test("Loading backups succeeds", [.loading, .backup])
    func testBackupLoading() async throws {
        // Given: Test context and mock backups
        let context = TestContext()
        let viewModel = context.createViewModel()
        context.backupManager.mockBackups = MockData.Backup.validBackups
        
        // When: Loading backups
        await viewModel.loadBackups()
        
        // Then: Backups are loaded correctly
        #expect(viewModel.backups == MockData.Backup.validBackups)
        #expect(!viewModel.isLoading)
        #expect(!viewModel.showError)
    }
    
    @Test("Creating backup with valid configuration succeeds", [.create, .backup])
    func testBackupCreation() async throws {
        // Given: Test context and mock data
        let context = TestContext()
        let viewModel = context.createViewModel()
        let newBackup = MockData.Backup.validBackup
        
        // When: Creating backup
        await viewModel.createBackup(newBackup)
        
        // Then: Backup is created and added to list
        #expect(context.backupManager.createBackupCalled)
        #expect(viewModel.backups.contains(where: { $0.id == newBackup.id }))
        #expect(!viewModel.isLoading)
        #expect(!viewModel.showError)
    }
    
    @Test("Executing backup triggers progress tracking", [.execute, .backup])
    func testBackupExecution() async throws {
        // Given: Test context and mock backup
        let context = TestContext()
        let viewModel = context.createViewModel()
        let backup = MockData.Backup.validBackup
        context.backupManager.mockBackups = [backup]
        
        // When: Executing backup
        await viewModel.executeBackup(backup)
        
        // Then: Backup is executed successfully
        #expect(context.backupManager.executeBackupCalled)
        #expect(context.progressTracker.startTrackingCalled)
        #expect(!viewModel.isLoading)
        #expect(!viewModel.showError)
    }
    
    @Test("Error handling for various backup errors", [.error, .backup],
          arguments: MockData.Error.backupErrors)
    func testErrorHandling(_ error: BackupError) async throws {
        // Given: Test context and view model
        var context = TestContext()
        let viewModel = context.createViewModel()
        
        // Setup error condition
        context.backupManager.simulateError = error
        
        // When: Loading backups
        await viewModel.loadBackups()
        
        // Then: Error is handled correctly
        #expect(!viewModel.isLoading)
        #expect(viewModel.showError)
        #expect(viewModel.error != nil)
        if let backupError = viewModel.error as? BackupError {
            #expect(backupError == error)
        }
    }
    
    @Test("Performance meets requirements", [.performance, .viewModel],
          traits: .executionTime(10.0))
    func testPerformance() async throws {
        // Given: Test context and view model
        var context = TestContext()
        let viewModel = context.createViewModel()
        
        // When: Performing operations
        let startTime = context.dateProvider.currentDate()
        
        for _ in 0..<100 {
            await viewModel.loadBackups()
        }
        
        let endTime = context.dateProvider.currentDate()
        
        // Then: Operations complete within time limit
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 5.0, "Batch operations should complete in under 5 seconds")
        
        // Test individual operation performance
        let operationStart = context.dateProvider.currentDate()
        await viewModel.loadBackups()
        let operationEnd = context.dateProvider.currentDate()
        
        let operationInterval = operationEnd.timeIntervalSince(operationStart)
        #expect(operationInterval < 0.1, "Individual operations should complete in under 0.1 seconds")
    }
}
