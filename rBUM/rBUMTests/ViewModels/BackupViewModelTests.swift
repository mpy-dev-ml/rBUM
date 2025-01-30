//
//  BackupViewModelTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
@testable import rBUM

final class BackupViewModelTests: XCTestCase {
    var resticService: TestMocks.MockResticCommandService!
    var credentialsManager: TestMocks.MockCredentialsManager!
    var viewModel: BackupViewModel!
    var repository: Repository!
    
    override func setUp() {
        super.setUp()
        resticService = TestMocks.MockResticCommandService()
        credentialsManager = TestMocks.MockCredentialsManager()
        repository = Repository(name: "Test Repo", path: URL(fileURLWithPath: "/test/repo"))
        viewModel = BackupViewModel(
            repository: repository,
            resticService: resticService,
            credentialsManager: credentialsManager
        )
    }
    
    override func tearDown() {
        resticService = nil
        credentialsManager = nil
        viewModel = nil
        repository = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(viewModel.selectedPaths.isEmpty)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.currentStatus)
        XCTAssertNil(viewModel.currentProgress)
        XCTAssertEqual(viewModel.progressMessage, "Ready to start backup")
        XCTAssertEqual(viewModel.progressPercentage, 0)
    }
    
    func testBackupProgress() async {
        // Given
        let paths = [URL(fileURLWithPath: "/test/file1")]
        viewModel.selectedPaths = paths
        credentialsManager.passwords[repository.id] = "testPassword"
        
        // When
        let progressExpectation = expectation(description: "Progress update received")
        let statusExpectation = expectation(description: "Status update received")
        
        // Start backup and wait for completion
        await viewModel.startBackup()
        
        // Then
        XCTAssertNotNil(viewModel.currentProgress)
        if case .inProgress(let progress) = viewModel.state {
            XCTAssertEqual(progress.totalFiles, 10)
            XCTAssertEqual(progress.processedFiles, 5)
            XCTAssertEqual(progress.totalBytes, 1024)
            XCTAssertEqual(progress.processedBytes, 512)
            XCTAssertEqual(progress.currentFile, "/test/file.txt")
            XCTAssertEqual(progress.estimatedSecondsRemaining, 10)
            progressExpectation.fulfill()
        }
        
        if let status = viewModel.currentStatus {
            XCTAssertEqual(status, .completed)
            statusExpectation.fulfill()
        }
        
        await fulfillment(of: [progressExpectation, statusExpectation], timeout: 5)
        
        // Verify final state
        XCTAssertEqual(viewModel.state, .completed)
        XCTAssertEqual(viewModel.progressPercentage, 100)
        XCTAssertEqual(viewModel.progressMessage, "Backup completed successfully")
    }
    
    func testBackupFailure() async {
        // Given
        let paths = [URL(fileURLWithPath: "/test/file1")]
        viewModel.selectedPaths = paths
        credentialsManager.passwords[repository.id] = "testPassword"
        
        let testError = ResticError.backupFailed("Test error")
        resticService.backupError = testError
        
        // When
        await viewModel.startBackup()
        
        // Then
        XCTAssertEqual(viewModel.state, .failed(testError))
        XCTAssertTrue(viewModel.showError)
        XCTAssertEqual(viewModel.progressPercentage, 0)
        XCTAssertEqual(viewModel.progressMessage, "Backup failed: \(testError.localizedDescription)")
    }
    
    func testReset() {
        // Given
        viewModel.selectedPaths = [URL(fileURLWithPath: "/test/file1")]
        viewModel.showError = true
        
        // When
        viewModel.reset()
        
        // Then
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(viewModel.selectedPaths.isEmpty)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.currentStatus)
        XCTAssertNil(viewModel.currentProgress)
        XCTAssertEqual(viewModel.progressMessage, "Ready to start backup")
        XCTAssertEqual(viewModel.progressPercentage, 0)
    }
}
