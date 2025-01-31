//
//  BackupManagerTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupManager functionality
struct BackupManagerTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let fileManager: MockFileManager
        let dateProvider: MockDateProvider
        let notificationCenter: MockNotificationCenter
        let resticService: MockResticService
        let repositoryStorage: MockRepositoryStorage
        let keychain: MockKeychain
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.fileManager = MockFileManager()
            self.dateProvider = MockDateProvider()
            self.notificationCenter = MockNotificationCenter()
            self.resticService = MockResticService()
            self.repositoryStorage = MockRepositoryStorage()
            self.keychain = MockKeychain()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            fileManager.reset()
            dateProvider.reset()
            notificationCenter.reset()
            resticService.reset()
            repositoryStorage.reset()
            keychain.reset()
        }
        
        /// Create test manager
        func createManager() -> BackupManager {
            BackupManager(
                resticService: resticService,
                repositoryStorage: repositoryStorage,
                keychain: keychain,
                dateProvider: dateProvider,
                notificationCenter: notificationCenter
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup manager", tags: ["init", "manager"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating manager
        let manager = context.createManager()
        
        // Then: Manager is configured correctly
        #expect(manager.isReady)
        #expect(manager.activeJobs.isEmpty)
        #expect(manager.completedJobs.isEmpty)
    }
    
    // MARK: - Repository Management Tests
    
    @Test("Test repository management", tags: ["repository", "manager"])
    func testRepositoryManagement() async throws {
        // Given: Manager and test repository
        let context = TestContext()
        let manager = context.createManager()
        
        let repository = MockData.Repository.validRepository
        let credentials = MockData.Credentials.validCredentials
        
        // When: Adding repository
        try await manager.addRepository(repository, credentials: credentials)
        
        // Then: Repository is stored
        #expect(context.repositoryStorage.repositories.count == 1)
        #expect(context.repositoryStorage.repositories.first == repository)
        #expect(context.keychain.hasCredentials(for: repository.id))
        
        // When: Removing repository
        try await manager.removeRepository(repository)
        
        // Then: Repository is removed
        #expect(context.repositoryStorage.repositories.isEmpty)
        #expect(!context.keychain.hasCredentials(for: repository.id))
    }
    
    // MARK: - Backup Job Tests
    
    @Test("Test backup job management", tags: ["job", "manager"])
    func testBackupJobManagement() async throws {
        // Given: Manager and test data
        let context = TestContext()
        let manager = context.createManager()
        
        let repository = MockData.Repository.validRepository
        let configuration = MockData.Configuration.validConfiguration
        
        // When: Creating backup job
        let job = try await manager.createBackupJob(
            repository: repository,
            configuration: configuration
        )
        
        // Then: Job is created correctly
        #expect(manager.activeJobs.count == 1)
        #expect(job.repository == repository)
        #expect(job.configuration == configuration)
        #expect(job.status == .pending)
        
        // When: Starting job
        try await manager.startJob(job)
        
        // Then: Job is running
        #expect(job.status == .running)
        #expect(context.resticService.backupCalled)
        
        // When: Completing job
        try await manager.completeJob(job)
        
        // Then: Job is completed
        #expect(job.status == .completed)
        #expect(manager.activeJobs.isEmpty)
        #expect(manager.completedJobs.count == 1)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test error handling", tags: ["error", "manager"])
    func testErrorHandling() async throws {
        // Given: Manager and test data
        let context = TestContext()
        let manager = context.createManager()
        
        let repository = MockData.Repository.validRepository
        let configuration = MockData.Configuration.validConfiguration
        
        // Configure service to fail
        context.resticService.shouldFail = true
        
        // When: Creating and running job
        let job = try await manager.createBackupJob(
            repository: repository,
            configuration: configuration
        )
        
        do {
            try await manager.startJob(job)
            throw TestFailure("Expected error")
        } catch {
            // Then: Error is handled correctly
            #expect(job.status == .failed)
            #expect(job.error != nil)
            #expect(manager.activeJobs.isEmpty)
            #expect(manager.failedJobs.count == 1)
        }
    }
    
    // MARK: - Concurrent Job Tests
    
    @Test("Test concurrent job handling", tags: ["concurrent", "manager"])
    func testConcurrentJobs() async throws {
        // Given: Manager and test data
        let context = TestContext()
        let manager = context.createManager()
        
        let repositories = [
            MockData.Repository.validRepository,
            MockData.Repository.customRepository
        ]
        
        let configurations = [
            MockData.Configuration.validConfiguration,
            MockData.Configuration.customConfiguration
        ]
        
        // When: Creating multiple jobs
        var jobs: [BackupJob] = []
        for (repository, configuration) in zip(repositories, configurations) {
            let job = try await manager.createBackupJob(
                repository: repository,
                configuration: configuration
            )
            jobs.append(job)
        }
        
        // Then: Jobs are managed correctly
        #expect(manager.activeJobs.count == jobs.count)
        
        // When: Starting jobs concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for job in jobs {
                group.addTask {
                    try await manager.startJob(job)
                }
            }
        }
        
        // Then: All jobs are processed
        #expect(manager.activeJobs.count == jobs.count)
        for job in jobs {
            #expect(job.status == .running)
        }
    }
    
    // MARK: - Job Queue Tests
    
    @Test("Test job queue management", tags: ["queue", "manager"])
    func testJobQueue() async throws {
        // Given: Manager and test data
        let context = TestContext()
        let manager = context.createManager()
        
        let repository = MockData.Repository.validRepository
        let configurations = [
            MockData.Configuration.validConfiguration,
            MockData.Configuration.customConfiguration
        ]
        
        // When: Queueing multiple jobs
        for configuration in configurations {
            _ = try await manager.queueBackupJob(
                repository: repository,
                configuration: configuration
            )
        }
        
        // Then: Jobs are queued correctly
        #expect(manager.queuedJobs.count == configurations.count)
        
        // When: Processing queue
        try await manager.processQueue()
        
        // Then: Jobs are processed in order
        #expect(manager.queuedJobs.isEmpty)
        #expect(manager.completedJobs.count == configurations.count)
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle manager edge cases", tags: ["edge", "manager"])
    func testEdgeCases() async throws {
        // Given: Manager
        let context = TestContext()
        let manager = context.createManager()
        
        // Test invalid repository
        do {
            _ = try await manager.createBackupJob(
                repository: MockData.Repository.invalidRepository,
                configuration: MockData.Configuration.validConfiguration
            )
            throw TestFailure("Expected error for invalid repository")
        } catch {
            // Expected error
        }
        
        // Test invalid configuration
        do {
            _ = try await manager.createBackupJob(
                repository: MockData.Repository.validRepository,
                configuration: MockData.Configuration.invalidConfiguration
            )
            throw TestFailure("Expected error for invalid configuration")
        } catch {
            // Expected error
        }
        
        // Test duplicate job
        let repository = MockData.Repository.validRepository
        let configuration = MockData.Configuration.validConfiguration
        
        let job1 = try await manager.createBackupJob(
            repository: repository,
            configuration: configuration
        )
        
        do {
            _ = try await manager.createBackupJob(
                repository: repository,
                configuration: configuration
            )
            throw TestFailure("Expected error for duplicate job")
        } catch {
            // Expected error
        }
        
        // Test cancelling non-existent job
        do {
            try await manager.cancelJob(MockData.Job.invalidJob)
            throw TestFailure("Expected error for non-existent job")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Authentication Tests
    
    @Test("Test multiple authentication methods", tags: ["auth", "security"])
    func testMultipleAuthMethods() async throws {
        // Given: Manager and test repositories
        let context = TestContext()
        let manager = context.createManager()
        
        // Test case 1: Password authentication
        let passwordRepo = MockData.Repository.createWithAuth(.password)
        let passwordCreds = MockData.Credentials.createPassword()
        try await manager.addRepository(passwordRepo, credentials: passwordCreds)
        
        // Verify password auth
        #expect(context.keychain.hasCredentials(for: passwordRepo.id))
        #expect(context.keychain.getCredentials(for: passwordRepo.id)?.type == .password)
        
        // Test case 2: Key file authentication
        let keyFileRepo = MockData.Repository.createWithAuth(.keyFile)
        let keyFileCreds = MockData.Credentials.createKeyFile()
        try await manager.addRepository(keyFileRepo, credentials: keyFileCreds)
        
        // Verify key file auth
        #expect(context.keychain.hasCredentials(for: keyFileRepo.id))
        #expect(context.keychain.getCredentials(for: keyFileRepo.id)?.type == .keyFile)
        #expect(context.fileManager.fileExists(atPath: keyFileCreds.keyFilePath))
        
        // Test case 3: Multiple key files
        let multiKeyRepo = MockData.Repository.createWithAuth(.multiKey)
        let multiKeyCreds = MockData.Credentials.createMultipleKeyFiles()
        try await manager.addRepository(multiKeyRepo, credentials: multiKeyCreds)
        
        // Verify multiple key files
        #expect(context.keychain.hasCredentials(for: multiKeyRepo.id))
        #expect(context.keychain.getCredentials(for: multiKeyRepo.id)?.type == .multiKey)
        #expect(multiKeyCreds.keyFilePaths.allSatisfy { context.fileManager.fileExists(atPath: $0) })
        
        // Test authentication failure handling
        context.keychain.simulateAuthFailure = true
        do {
            try await manager.authenticate(passwordRepo)
            XCTFail("Should have thrown authentication error")
        } catch {
            #expect(error is BackupError)
            #expect((error as? BackupError)?.isAuthenticationError == true)
        }
    }
    
    // MARK: - Cache Tests
    
    @Test("Test encrypted cache handling", tags: ["cache", "security"])
    func testEncryptedCache() async throws {
        // Given: Manager with cache configuration
        let context = TestContext()
        let manager = context.createManager()
        
        let repository = MockData.Repository.validRepository
        let cacheData = MockData.Cache.validCacheData
        
        // When: Writing to cache
        try await manager.writeToCache(repository.id, data: cacheData)
        
        // Then: Cache is encrypted
        let cachedData = try context.fileManager.contentsOfFile(repository.cachePath)
        #expect(!cachedData.contains(cacheData)) // Raw data should not be visible
        
        // Verify cache encryption
        #expect(context.securityService.encryptCalled)
        #expect(context.securityService.lastEncryptedData != nil)
        
        // When: Reading from cache
        let retrievedData = try await manager.readFromCache(repository.id)
        
        // Then: Data is correctly decrypted
        #expect(retrievedData == cacheData)
        #expect(context.securityService.decryptCalled)
        
        // Test cache invalidation
        try await manager.invalidateCache(repository.id)
        #expect(!context.fileManager.fileExists(atPath: repository.cachePath))
        
        // Test cache migration
        let oldCacheData = MockData.Cache.oldCacheData
        try await manager.migrateCache(repository.id, from: oldCacheData)
        #expect(try await manager.readFromCache(repository.id) == oldCacheData)
    }
    
    // MARK: - Repository Integrity Tests
    
    @Test("Test repository integrity verification", tags: ["integrity", "security"])
    func testRepositoryIntegrity() async throws {
        // Given: Manager and test repository
        let context = TestContext()
        let manager = context.createManager()
        
        let repository = MockData.Repository.validRepository
        try await manager.addRepository(repository, credentials: MockData.Credentials.validCredentials)
        
        // Test case 1: Basic integrity check
        let integrityResult = try await manager.verifyRepositoryIntegrity(repository.id)
        #expect(integrityResult.isValid)
        #expect(integrityResult.checksumMatch)
        #expect(context.resticService.checkCalled)
        
        // Test case 2: Detect corruption
        context.resticService.simulateCorruption = true
        let corruptResult = try await manager.verifyRepositoryIntegrity(repository.id)
        #expect(!corruptResult.isValid)
        #expect(!corruptResult.checksumMatch)
        #expect(corruptResult.errors.contains(where: { $0.isCorruptionError }))
        
        // Test case 3: Repair attempt
        try await manager.repairRepository(repository.id)
        #expect(context.resticService.repairCalled)
        
        // Verify repair success
        context.resticService.simulateCorruption = false
        let repairedResult = try await manager.verifyRepositoryIntegrity(repository.id)
        #expect(repairedResult.isValid)
        
        // Test case 4: Index verification
        let indexResult = try await manager.verifyRepositoryIndex(repository.id)
        #expect(indexResult.isValid)
        #expect(indexResult.indexComplete)
        #expect(context.resticService.indexCalled)
        
        // Test case 5: Pack file verification
        let packResult = try await manager.verifyRepositoryPacks(repository.id)
        #expect(packResult.isValid)
        #expect(packResult.packsComplete)
        #expect(context.resticService.packsCalled)
        
        // Test case 6: Snapshot verification
        let snapshotResult = try await manager.verifyRepositorySnapshots(repository.id)
        #expect(snapshotResult.isValid)
        #expect(snapshotResult.snapshotsComplete)
        #expect(context.resticService.snapshotsCalled)
    }

    // MARK: - Mock Implementations

    /// Mock implementation of UserDefaults for testing
    final class MockUserDefaults: UserDefaults {
        var storage: [String: Any] = [:]
        
        override func set(_ value: Any?, forKey defaultName: String) {
            if let value = value {
                storage[defaultName] = value
            } else {
                storage.removeValue(forKey: defaultName)
            }
        }
        
        override func object(forKey defaultName: String) -> Any? {
            storage[defaultName]
        }
        
        override func removeObject(forKey defaultName: String) {
            storage.removeValue(forKey: defaultName)
        }
        
        func reset() {
            storage.removeAll()
        }
    }

    /// Mock implementation of FileManager for testing
    final class MockFileManager: FileManager {
        var files: Set<String> = []
        var directories: Set<String> = []
        
        override func fileExists(atPath path: String) -> Bool {
            files.contains(path)
        }
        
        override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
            if let isDirectory = isDirectory {
                isDirectory.pointee = ObjCBool(directories.contains(path))
            }
            return files.contains(path) || directories.contains(path)
        }
        
        func addFile(_ path: String) {
            files.insert(path)
        }
        
        func addDirectory(_ path: String) {
            directories.insert(path)
        }
        
        func reset() {
            files.removeAll()
            directories.removeAll()
        }
    }

    /// Mock implementation of DateProvider for testing
    final class MockDateProvider: DateProvider {
        var currentDate: Date = Date()
        
        func now() -> Date {
            currentDate
        }
        
        func setDate(_ date: Date) {
            currentDate = date
        }
        
        func reset() {
            currentDate = Date()
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

    /// Mock implementation of ResticService for testing
    final class MockResticService: ResticServiceProtocol {
        var backupCalled = false
        var lastBackupConfiguration: BackupConfiguration?
        var shouldFail = false
        
        func backup(_ configuration: BackupConfiguration) async throws {
            backupCalled = true
            lastBackupConfiguration = configuration
            if shouldFail {
                throw MockData.Error.backupError
            }
        }
        
        func reset() {
            backupCalled = false
            lastBackupConfiguration = nil
            shouldFail = false
        }
    }

    /// Mock implementation of RepositoryStorage for testing
    final class MockRepositoryStorage: RepositoryStorageProtocol {
        var repositories: [Repository] = []
        
        func store(_ repository: Repository) throws {
            repositories.append(repository)
        }
        
        func remove(_ repository: Repository) throws {
            repositories.removeAll { $0.id == repository.id }
        }
        
        func repository(withId id: UUID) throws -> Repository? {
            repositories.first { $0.id == id }
        }
        
        func reset() {
            repositories.removeAll()
        }
    }

    /// Mock implementation of Keychain for testing
    final class MockKeychain: KeychainProtocol {
        var credentials: [UUID: Credentials] = [:]
        
        func store(_ credentials: Credentials, for id: UUID) throws {
            self.credentials[id] = credentials
        }
        
        func retrieve(for id: UUID) throws -> Credentials? {
            credentials[id]
        }
        
        func remove(for id: UUID) throws {
            credentials.removeValue(forKey: id)
        }
        
        func hasCredentials(for id: UUID) -> Bool {
            credentials[id] != nil
        }
        
        func reset() {
            credentials.removeAll()
        }
    }

}
