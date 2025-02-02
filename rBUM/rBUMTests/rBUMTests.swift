//
//  rBUMTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
import Foundation
@testable import rBUM
import Combine

/// Main test suite for rBUM application
final class rBUMTests: XCTestCase {
    // MARK: - Test Types
    
    typealias TestMocks = TestMocksModule.TestMocks
    
    // MARK: - Test Context
    
    /// Test environment with all dependencies
    struct TestContext {
        let backupService: BackupServiceProtocol
        let repositoryService: RepositoryServiceProtocol
        let credentialsManager: CredentialsManagerProtocol
        let notificationCenter: NotificationCenter
        let fileManager: FileManagerProtocol
        
        init() {
            self.backupService = TestMocks.MockBackupService()
            self.repositoryService = TestMocks.MockRepositoryService()
            self.credentialsManager = TestMocks.MockCredentialsManager()
            self.notificationCenter = TestMocks.MockNotificationCenter()
            self.fileManager = TestMocks.MockFileManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            (backupService as? TestMocks.MockBackupService)?.reset()
            (repositoryService as? TestMocks.MockRepositoryService)?.reset()
            (credentialsManager as? TestMocks.MockCredentialsManager)?.reset()
            (notificationCenter as? TestMocks.MockNotificationCenter)?.reset()
            (fileManager as? TestMocks.MockFileManager)?.reset()
        }
    }
    
    // MARK: - Test Lifecycle
    
    override func setUp() {
        super.setUp()
        // Additional setup if needed
    }
    
    override func tearDown() {
        // Clean up after each test
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testBackupWorkflow() async throws {
        // Given: Test context with mock services
        let context = TestContext()
        
        // Setup test data
        let repository = MockData.Repository.validRepository
        let credentials = MockData.Repository.validCredentials
        let backup = MockData.Backup.validBackup
        
        // When: Store repository and credentials
        try await context.repositoryService.store(repository)
        try await context.credentialsManager.store(credentials)
        
        // Then: Create backup
        try await context.backupService.createBackup(
            paths: backup.paths,
            to: repository,
            credentials: credentials,
            tags: backup.tags,
            onProgress: { _ in },
            onStatusChange: { _ in }
        )
        
        // Verify notifications were posted
        XCTAssertFalse(context.notificationCenter.postedNotifications.isEmpty)
    }
    
    func testRepositoryManagement() async throws {
        // Given: Test context with mock services
        let context = TestContext()
        
        // Setup test data
        let repository = MockData.Repository.validRepository
        let updatedRepo = MockData.Repository.validRepository
        
        // When: Execute management operations
        try await context.repositoryService.store(repository)
        try await context.repositoryService.store(updatedRepo)
        try await context.repositoryService.delete(forId: updatedRepo.id)
        
        // Then: Management operations complete successfully
        let repositories = try await context.repositoryService.list()
        XCTAssertTrue(repositories.isEmpty, "All repositories should be deleted")
        XCTAssertFalse(context.notificationCenter.postedNotifications.isEmpty, "Notifications should be posted")
    }
}
