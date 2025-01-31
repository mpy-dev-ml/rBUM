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
    // MARK: - Test Context
    
    /// Test environment with all dependencies
    struct TestContext {
        let backupService: rBUMTests.MockBackupService
        let repositoryService: rBUMTests.MockRepositoryService
        let credentialsManager: rBUMTests.MockCredentialsManager
        let notificationCenter: rBUMTests.MockNotificationCenter
        let fileManager: rBUMTests.MockFileManager
        
        init() {
            self.backupService = rBUMTests.MockBackupService()
            self.repositoryService = rBUMTests.MockRepositoryService()
            self.credentialsManager = rBUMTests.MockCredentialsManager()
            self.notificationCenter = rBUMTests.MockNotificationCenter()
            self.fileManager = rBUMTests.MockFileManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            backupService.reset()
            repositoryService.reset()
            credentialsManager.reset()
            notificationCenter.reset()
            fileManager.reset()
        }
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

// MARK: - Mock Services
extension rBUMTests {
    final class MockBackupService: BackupServiceProtocol {
        private var error: Error?
        
        func reset() {
            error = nil
        }
        
        func setError(_ error: Error) {
            self.error = error
        }
        
        func createBackup(
            paths: [URL],
            to repository: Repository,
            credentials: RepositoryCredentials,
            tags: [String]?,
            onProgress: ((BackupProgress) -> Void)?,
            onStatusChange: ((BackupStatus) -> Void)?
        ) async throws {
            if let error = error { throw error }
            
            // Simulate backup progress
            onStatusChange?(.preparing)
            onProgress?(BackupProgress(totalFiles: 100, processedFiles: 0, totalBytes: 1024 * 1024, processedBytes: 0))
            
            // Simulate backup completion
            onStatusChange?(.completed)
            onProgress?(BackupProgress(totalFiles: 100, processedFiles: 100, totalBytes: 1024 * 1024, processedBytes: 1024 * 1024))
        }
    }
    
    final class MockRepositoryService: RepositoryServiceProtocol {
        private var repositories: [Repository] = []
        private var error: Error?
        
        func reset() {
            repositories = []
            error = nil
        }
        
        func setError(_ error: Error) {
            self.error = error
        }
        
        func store(_ repository: Repository) async throws {
            if let error = error { throw error }
            if let existing = repositories.firstIndex(where: { $0.id == repository.id }) {
                repositories[existing] = repository
            } else {
                repositories.append(repository)
            }
        }
        
        func list() async throws -> [Repository] {
            if let error = error { throw error }
            return repositories
        }
        
        func delete(forId id: UUID) async throws {
            if let error = error { throw error }
            repositories.removeAll { $0.id == id }
        }
        
        func exists(atPath path: URL, excludingId: UUID?) async throws -> Bool {
            if let error = error { throw error }
            return repositories.contains { repository in
                repository.path == path && repository.id != excludingId
            }
        }
    }
    
    final class MockNotificationCenter: NotificationCenterProtocol {
        private var notifications: [(name: Notification.Name, object: Any?)] = []
        private var error: Error?
        
        var postedNotifications: [(name: Notification.Name, object: Any?)] {
            notifications
        }
        
        func reset() {
            notifications = []
            error = nil
        }
        
        func setError(_ error: Error) {
            self.error = error
        }
        
        func post(name: Notification.Name, object: Any?) {
            notifications.append((name: name, object: object))
        }
    }
    
    final class MockFileManager: FileManagerProtocol {
        private var files: Set<String> = []
        private var directories: Set<String> = []
        private var error: Error?
        
        func reset() {
            files = []
            directories = []
            error = nil
        }
        
        func setError(_ error: Error) {
            self.error = error
        }
        
        func addFile(at path: String) {
            files.insert(path)
        }
        
        func addDirectory(at path: String) {
            directories.insert(path)
        }
        
        func fileExists(atPath path: String) -> Bool {
            files.contains(path)
        }
        
        func directoryExists(at url: URL) -> Bool {
            directories.contains(url.path)
        }
        
        func createDirectory(at url: URL) throws {
            if let error = error { throw error }
            directories.insert(url.path)
        }
        
        func removeItem(at url: URL) throws {
            if let error = error { throw error }
            files.remove(url.path)
            directories.remove(url.path)
        }
        
        func contentsOfDirectory(at url: URL) throws -> [URL] {
            if let error = error { throw error }
            let path = url.path
            let contents = files.union(directories).filter { $0.hasPrefix(path) }
            return contents.map { URL(fileURLWithPath: $0) }
        }
    }
    
    final class MockCredentialsManager: CredentialsManagerProtocol {
        private var credentials: [RepositoryCredentials] = []
        private var error: Error?
        
        func reset() {
            credentials = []
            error = nil
        }
        
        func setError(_ error: Error) {
            self.error = error
        }
        
        func store(_ credentials: RepositoryCredentials) async throws {
            if let error = error { throw error }
            self.credentials.append(credentials)
        }
        
        func retrieve(forId id: UUID) async throws -> RepositoryCredentials {
            if let error = error { throw error }
            guard let credentials = credentials.first(where: { $0.repositoryId == id }) else {
                throw CredentialsError.notFound
            }
            return credentials
        }
        
        func update(_ credentials: RepositoryCredentials) async throws {
            if let error = error { throw error }
            guard let index = self.credentials.firstIndex(where: { $0.repositoryId == credentials.repositoryId }) else {
                throw CredentialsError.notFound
            }
            self.credentials[index] = credentials
        }
        
        func delete(forId id: UUID) async throws {
            if let error = error { throw error }
            guard credentials.contains(where: { $0.repositoryId == id }) else {
                throw CredentialsError.notFound
            }
            credentials.removeAll { $0.repositoryId == id }
        }
        
        func getPassword(forRepositoryId id: UUID) async throws -> String {
            if let error = error { throw error }
            guard let credentials = credentials.first(where: { $0.repositoryId == id }) else {
                throw CredentialsError.notFound
            }
            return credentials.password
        }
        
        func createCredentials(id: UUID, path: String, password: String) -> RepositoryCredentials {
            RepositoryCredentials(
                repositoryId: id,
                password: password,
                repositoryPath: path
            )
        }
    }
}
