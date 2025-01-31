import Testing
@testable import rBUM

/// Tests for BackupViewModel functionality
struct BackupViewModelTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let backupService: MockBackupService
        let resticService: MockResticService
        let notificationCenter: MockNotificationCenter
        let progressTracker: MockProgressTracker
        let dateProvider: MockDateProvider
        let userDefaults: MockUserDefaults
        
        init() {
            self.backupService = MockBackupService()
            self.resticService = MockResticService()
            self.notificationCenter = MockNotificationCenter()
            self.progressTracker = MockProgressTracker()
            self.dateProvider = MockDateProvider()
            self.userDefaults = MockUserDefaults()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            backupService.reset()
            resticService.reset()
            notificationCenter.reset()
            progressTracker.reset()
            dateProvider.reset()
            userDefaults.reset()
        }
        
        /// Create test view model
        func createViewModel() -> BackupViewModel {
            BackupViewModel(
                backupService: backupService,
                resticService: resticService,
                notificationCenter: notificationCenter,
                progressTracker: progressTracker,
                dateProvider: dateProvider,
                userDefaults: userDefaults
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Test view model initialization", tags: ["init", "viewmodel"])
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
    
    // MARK: - Backup Loading Tests
    
    @Test("Test backup loading", tags: ["loading", "backup"])
    func testBackupLoading() async throws {
        // Given: Test context and mock backups
        let context = TestContext()
        let viewModel = context.createViewModel()
        context.backupService.mockBackups = MockData.Backup.validBackups
        
        // When: Loading backups
        await viewModel.loadBackups()
        
        // Then: Backups are loaded correctly
        #expect(viewModel.backups == MockData.Backup.validBackups)
        #expect(!viewModel.isLoading)
        #expect(!viewModel.showError)
    }
    
    // MARK: - Backup Creation Tests
    
    @Test("Test backup creation", tags: ["create", "backup"])
    func testBackupCreation() async throws {
        // Given: Test context and mock data
        let context = TestContext()
        let viewModel = context.createViewModel()
        let newBackup = MockData.Backup.validBackup
        
        // When: Creating a new backup
        await viewModel.createBackup(newBackup)
        
        // Then: Backup is created and added to list
        #expect(context.backupService.createBackupCalled)
        #expect(viewModel.backups.contains(where: { $0.id == newBackup.id }))
        #expect(!viewModel.isLoading)
        #expect(!viewModel.showError)
    }
    
    // MARK: - Backup Execution Tests
    
    @Test("Test backup execution", tags: ["execute", "backup"])
    func testBackupExecution() async throws {
        // Given: Test context and mock backup
        let context = TestContext()
        let viewModel = context.createViewModel()
        let backup = MockData.Backup.validBackup
        context.backupService.mockBackups = [backup]
        
        // When: Executing backup
        await viewModel.executeBackup(backup)
        
        // Then: Backup is executed successfully
        #expect(context.backupService.executeBackupCalled)
        #expect(context.progressTracker.startTrackingCalled)
        #expect(!viewModel.isLoading)
        #expect(!viewModel.showError)
    }
    
    // MARK: - Backup Selection Tests
    
    @Test("Test backup selection", tags: ["selection", "viewmodel"])
    func testBackupSelection() async throws {
        // Given: Test context and view model
        let context = TestContext()
        let viewModel = context.createViewModel()
        
        let testCases = MockData.Backup.selectionData
        
        // Test selection scenarios
        for testCase in testCases {
            // Setup mock data
            context.backupService.mockBackups = testCase.backups
            await viewModel.loadBackups()
            
            // Select backup
            viewModel.selectBackup(testCase.selectedId)
            
            // Verify selection state
            #expect(viewModel.selectedBackup?.id == testCase.selectedId)
            #expect(viewModel.selectedBackupDetails == testCase.expectedDetails)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test error handling", tags: ["error", "viewmodel"])
    func testErrorHandling() async throws {
        // Given: Test context and view model
        let context = TestContext()
        let viewModel = context.createViewModel()
        
        let errorCases = MockData.Backup.errorCases
        
        // Test error scenarios
        for errorCase in errorCases {
            // Setup error condition
            context.backupService.simulateError = errorCase.error
            
            // Perform operation
            await errorCase.operation(viewModel)
            
            // Verify error handling
            #expect(viewModel.isLoading == false)
            #expect(viewModel.error != nil)
            if let error = viewModel.error as? BackupError {
                #expect(error.code == errorCase.expectedErrorCode)
            }
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
    }
    
    // MARK: - UI State Tests
    
    @Test("Test UI state updates", tags: ["ui", "viewmodel"])
    func testUIStateUpdates() async throws {
        // Given: Test context and view model
        let context = TestContext()
        let viewModel = context.createViewModel()
        
        let testCases = MockData.Backup.uiStateData
        
        // Test UI state scenarios
        for testCase in testCases {
            // Setup initial state
            context.backupService.mockBackups = testCase.backups
            context.progressTracker.mockProgress = testCase.progress
            
            // Perform UI updates
            await viewModel.loadBackups()
            viewModel.selectBackup(testCase.selectedId)
            
            // Verify UI state
            #expect(viewModel.isLoading == testCase.expectedLoading)
            #expect(viewModel.backups.count == testCase.expectedBackupCount)
            #expect(viewModel.selectedBackup?.id == testCase.selectedId)
            #expect(viewModel.backupProgress[testCase.selectedId]?.status == testCase.expectedStatus)
            
            context.reset()
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test view model performance", tags: ["performance", "viewmodel"])
    func testPerformance() async throws {
        // Given: Test context and view model
        let context = TestContext()
        let viewModel = context.createViewModel()
        
        let startTime = Date()
        
        // Perform multiple operations
        for i in 0..<100 {
            let backup = BackupConfiguration(
                id: UUID(),
                name: "Test Backup \(i)",
                settings: BackupSettings(),
                schedule: BackupSchedule()
            )
            await viewModel.createBackup(backup)
            await viewModel.loadBackups()
            viewModel.selectBackup(backup.id)
        }
        
        let endTime = Date()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 5.0) // Should complete in under 5 seconds
        
        // Test individual operation performance
        let backup = BackupConfiguration(
            id: UUID(),
            name: "Test Backup",
            settings: BackupSettings(),
            schedule: BackupSchedule()
        )
        
        let operationStart = Date()
        await viewModel.createBackup(backup)
        await viewModel.loadBackups()
        viewModel.selectBackup(backup.id)
        let operationEnd = Date()
        
        let operationInterval = operationEnd.timeIntervalSince(operationStart)
        #expect(operationInterval < 0.1) // Individual operations should be fast
    }
}
