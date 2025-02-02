//
//  TestMocks.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
@testable import rBUM

/// Module for all mock implementations used in tests
public struct TestMocksModule {
    /// All mock implementations
    public struct TestMocks {
        // MARK: - Repository Storage
        public final class MockRepositoryStorage: RepositoryStorageProtocol {
            var repositories: [Repository] = []
            var storeError: Error?
            var retrieveError: Error?
            var deleteError: Error?
            var existsError: Error?
            var existsResult: Bool = false
            
            func list() throws -> [Repository] {
                if let error = retrieveError { throw error }
                return repositories
            }
            
            func store(_ repository: Repository) throws {
                if let error = storeError { throw error }
                repositories.append(repository)
            }
            
            func delete(_ repository: Repository) throws {
                if let error = deleteError { throw error }
                repositories.removeAll { $0.id == repository.id }
            }
            
            func exists(_ repository: Repository) throws -> Bool {
                if let error = existsError { throw error }
                return existsResult
            }
            
            func reset() {
                repositories = []
                storeError = nil
                retrieveError = nil
                deleteError = nil
                existsError = nil
                existsResult = false
            }
        }
        
        // MARK: - Backup Service
        public final class MockBackupService: BackupServiceProtocol {
            private var backups: [Backup] = []
            private var error: Error?
            
            func createBackup(paths: [URL], to repository: Repository, credentials: RepositoryCredentials, tags: [String]?) async throws -> Backup {
                if let error = error { throw error }
                let backup = Backup(id: UUID(), paths: paths, repository: repository, tags: tags ?? [])
                backups.append(backup)
                return backup
            }
            
            func listBackups(for repository: Repository, credentials: RepositoryCredentials) async throws -> [Backup] {
                if let error = error { throw error }
                return backups
            }
            
            func setError(_ error: Error?) {
                self.error = error
            }
            
            func reset() {
                backups = []
                error = nil
            }
        }
        
        // MARK: - Backup Service
        public final class MockBackupService2: BackupServiceProtocol {
            private var error: Error?
            private(set) var backupCalled = false
            private(set) var restoreCalled = false
            private(set) var lastBackupPath: URL?
            private(set) var lastRestorePath: URL?
            
            public init() {}
            
            public func simulateError(_ error: Error?) {
                self.error = error
            }
            
            public func backup(repository: Repository, sourcePath: URL) async throws {
                if let error = error { throw error }
                backupCalled = true
                lastBackupPath = sourcePath
            }
            
            public func restore(repository: Repository, targetPath: URL) async throws {
                if let error = error { throw error }
                restoreCalled = true
                lastRestorePath = targetPath
            }
            
            public func reset() {
                error = nil
                backupCalled = false
                restoreCalled = false
                lastBackupPath = nil
                lastRestorePath = nil
            }
        }
        
        // MARK: - Restic Command Service
        public final class MockResticCommandService: ResticCommandServiceProtocol {
            var error: Error?
            var checkError: Error?
            var lastCommand: String?
            var lastRepository: Repository?
            var lastCredentials: RepositoryCredentials?
            var lastPassword: String?
            var status: RepositoryStatus = .valid
            
            func executeCommand(_ command: String, forRepository repository: Repository, withCredentials credentials: RepositoryCredentials) async throws {
                if let error = error {
                    throw error
                }
                lastCommand = command
                lastRepository = repository
                lastCredentials = credentials
            }
            
            func checkRepository(_ repository: URL, withPassword password: String) async throws -> RepositoryStatus {
                if let error = checkError {
                    throw error
                }
                lastPassword = password
                return status
            }
            
            func reset() {
                error = nil
                checkError = nil
                lastCommand = nil
                lastRepository = nil
                lastCredentials = nil
                lastPassword = nil
                status = .valid
            }
        }
        
        // MARK: - Restic Service
        public final class MockResticService: ResticServiceProtocol {
            private var error: Error?
            private(set) var initCalled = false
            private(set) var lastInitPath: String?
            private(set) var lastInitPassword: String?
            
            public init() {}
            
            public func simulateError(_ error: Error?) {
                self.error = error
            }
            
            public func initializeRepository(path: String, password: String) async throws {
                if let error = error { throw error }
                initCalled = true
                lastInitPath = path
                lastInitPassword = password
            }
            
            public func reset() {
                error = nil
                initCalled = false
                lastInitPath = nil
                lastInitPassword = nil
            }
        }
        
        // MARK: - Security Service
        public final class MockSecurityService: SecurityServiceProtocol {
            var error: Error?
            var encryptCalled = false
            var decryptCalled = false
            var generateKeyCalled = false
            var verifyKeyCalled = false
            var initializeSecurityCalled = false
            var verifySecurityCalled = false
            var lockCalled = false
            var unlockCalled = false
            
            func encrypt(_ data: Data, with key: Data) throws -> Data {
                if let error = error { throw error }
                encryptCalled = true
                return data
            }
            
            func decrypt(_ data: Data, with key: Data) throws -> Data {
                if let error = error { throw error }
                decryptCalled = true
                return data
            }
            
            func generateKey() throws -> String {
                if let error = error { throw error }
                generateKeyCalled = true
                return "test-key"
            }
            
            func verifyKey(_ key: String) throws -> Bool {
                if let error = error { throw error }
                verifyKeyCalled = true
                return true
            }
            
            func initializeSecurity(_ repository: Repository) throws {
                if let error = error { throw error }
                initializeSecurityCalled = true
            }
            
            func verifySecurity(_ repository: Repository) throws -> Bool {
                if let error = error { throw error }
                verifySecurityCalled = true
                return true
            }
            
            func lock(_ repository: Repository) throws {
                if let error = error { throw error }
                lockCalled = true
            }
            
            func unlock(_ repository: Repository) throws {
                if let error = error { throw error }
                unlockCalled = true
            }
            
            func reset() {
                error = nil
                encryptCalled = false
                decryptCalled = false
                generateKeyCalled = false
                verifyKeyCalled = false
                initializeSecurityCalled = false
                verifySecurityCalled = false
                lockCalled = false
                unlockCalled = false
            }
        }
        
        // MARK: - Keychain
        public final class MockKeychain: KeychainProtocol {
            var error: Error?
            var setPasswordCalled = false
            var getPasswordCalled = false
            var deletePasswordCalled = false
            var passwords: [String: String] = [:]
            
            func setPassword(_ password: String, forAccount account: String) throws {
                if let error = error { throw error }
                setPasswordCalled = true
                passwords[account] = password
            }
            
            func getPassword(forAccount account: String) throws -> String? {
                if let error = error { throw error }
                getPasswordCalled = true
                return passwords[account]
            }
            
            func deletePassword(forAccount account: String) throws {
                if let error = error { throw error }
                deletePasswordCalled = true
                passwords.removeValue(forKey: account)
            }
            
            func reset() {
                error = nil
                setPasswordCalled = false
                getPasswordCalled = false
                deletePasswordCalled = false
                passwords = [:]
            }
        }
        
        // MARK: - File Manager
        public final class MockFileManager: FileManagerProtocol {
            /// Error to simulate
            private var simulatedError: Error?
            
            /// Whether operations were called
            private(set) var createDirectoryCalled = false
            private(set) var removeItemCalled = false
            private(set) var fileExistsCalled = false
            private(set) var writeDataCalled = false
            private(set) var readDataCalled = false
            
            /// Last written data
            private(set) var lastWrittenData: Data?
            
            /// Stored files and directories
            private var files: [String: Data] = [:]
            private var directories: Set<String> = []
            
            /// Initialize mock file manager
            public init() {}
            
            /// Set error to simulate
            public func simulateError(_ error: Error?) {
                simulatedError = error
            }
            
            // MARK: - FileManagerProtocol
            
            public func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws {
                if let error = simulatedError { throw error }
                createDirectoryCalled = true
                directories.insert(url.path)
            }
            
            public func removeItem(at url: URL) throws {
                if let error = simulatedError { throw error }
                removeItemCalled = true
                files.removeValue(forKey: url.path)
                directories.remove(url.path)
            }
            
            public func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
                fileExistsCalled = true
                if let isDir = isDirectory {
                    isDir.pointee = directories.contains(path) ? true : false
                }
                return files[path] != nil || directories.contains(path)
            }
            
            public func write(_ data: Data, to url: URL) throws {
                if let error = simulatedError { throw error }
                writeDataCalled = true
                lastWrittenData = data
                files[url.path] = data
            }
            
            public func contents(atPath path: String) -> Data? {
                readDataCalled = true
                return files[path]
            }
            
            public func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor url: URL?, create: Bool) throws -> URL {
                if let error = simulatedError { throw error }
                let path = "/mock/\(directory.rawValue)"
                if create {
                    directories.insert(path)
                }
                return URL(fileURLWithPath: path)
            }
            
            /// Reset mock state
            public func reset() {
                simulatedError = nil
                createDirectoryCalled = false
                removeItemCalled = false
                fileExistsCalled = false
                writeDataCalled = false
                readDataCalled = false
                lastWrittenData = nil
                files = [:]
                directories = []
            }
        }
        
        // MARK: - Notification Center
        public final class MockNotificationCenter: NotificationCenter {
            public private(set) var postedNotifications: [(name: NSNotification.Name, object: Any?)] = []
            
            public override func post(name aName: NSNotification.Name, object anObject: Any?) {
                super.post(name: aName, object: anObject)
                postedNotifications.append((name: aName, object: anObject))
            }
            
            public func reset() {
                postedNotifications.removeAll()
            }
        }
        
        // MARK: - Date Provider
        public final class MockDateProvider: DateProviderProtocol {
            private var date: Date
            
            public init(date: Date = Date()) {
                self.date = date
            }
            
            public func currentDate() -> Date {
                return date
            }
            
            public func reset() {
                date = Date()
            }
            
            public func setDate(_ date: Date) {
                self.date = date
            }
        }
        
        // MARK: - Progress Tracker
        public final class MockProgressTracker: ProgressTrackerProtocol {
            private(set) var lastProgress: Double = 0
            private(set) var lastMessage: String?
            private(set) var updateCalled = false
            
            public init() {}
            
            public func updateProgress(_ progress: Double, message: String?) {
                updateCalled = true
                lastProgress = progress
                lastMessage = message
            }
            
            public func reset() {
                lastProgress = 0
                lastMessage = nil
                updateCalled = false
            }
        }
        
        // MARK: - Repository Creation Service
        public final class MockRepositoryCreationService: RepositoryCreationServiceProtocol {
            var createResult: Repository?
            var importResult: Repository?
            var createError: Error?
            var importError: Error?
            
            func create(at path: String, password: String) async throws -> Repository {
                if let error = createError { throw error }
                return createResult ?? Repository(id: UUID(), path: path)
            }
            
            func `import`(from path: String, password: String) async throws -> Repository {
                if let error = importError { throw error }
                return importResult ?? Repository(id: UUID(), path: path)
            }
        }
        
        // MARK: - Repository Service
        public final class MockRepositoryService: RepositoryServiceProtocol {
            private var error: Error?
            private(set) var createCalled = false
            private(set) var importCalled = false
            private(set) var lastCreatedRepository: Repository?
            private(set) var lastImportedRepository: Repository?
            
            public init() {}
            
            public func simulateError(_ error: Error?) {
                self.error = error
            }
            
            public func createRepository(name: String, path: URL, password: String) async throws -> Repository {
                if let error = error { throw error }
                createCalled = true
                let repository = Repository(id: UUID().uuidString, name: name, path: path.path)
                lastCreatedRepository = repository
                return repository
            }
            
            public func importRepository(path: URL, password: String) async throws -> Repository {
                if let error = error { throw error }
                importCalled = true
                let repository = Repository(id: UUID().uuidString, name: path.lastPathComponent, path: path.path)
                lastImportedRepository = repository
                return repository
            }
            
            public func reset() {
                error = nil
                createCalled = false
                importCalled = false
                lastCreatedRepository = nil
                lastImportedRepository = nil
            }
        }
        
        // MARK: - Credentials Manager
        public final class MockCredentialsManager: CredentialsManagerProtocol {
            var storeError: Error?
            var retrieveError: Error?
            var updateError: Error?
            var deleteError: Error?
            var getPasswordError: Error?
            var storedCredentials: [UUID: RepositoryCredentials] = [:]
            
            func store(_ credentials: RepositoryCredentials) async throws {
                if let error = storeError {
                    throw error
                }
                storedCredentials[credentials.repositoryId] = credentials
            }
            
            func retrieve(forId id: UUID) async throws -> RepositoryCredentials {
                if let error = retrieveError {
                    throw error
                }
                guard let credentials = storedCredentials[id] else {
                    throw CredentialsError.notFound
                }
                return credentials
            }
            
            func update(_ credentials: RepositoryCredentials) async throws {
                if let error = updateError {
                    throw error
                }
                storedCredentials[credentials.repositoryId] = credentials
            }
            
            func delete(forId id: UUID) async throws {
                if let error = deleteError {
                    throw error
                }
                storedCredentials.removeValue(forKey: id)
            }
            
            func getPassword(forRepositoryId id: UUID) async throws -> String {
                if let error = getPasswordError {
                    throw error
                }
                guard let credentials = storedCredentials[id] else {
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
        
        // MARK: - User Defaults
        public final class MockUserDefaults: UserDefaults {
            var storage: [String: Any] = [:]
            
            override func set(_ value: Any?, forKey defaultName: String) {
                storage[defaultName] = value
            }
            
            override func object(forKey defaultName: String) -> Any? {
                return storage[defaultName]
            }
            
            override func removeObject(forKey defaultName: String) {
                storage.removeValue(forKey: defaultName)
            }
            
            override func synchronize() -> Bool {
                return true
            }
            
            func reset() {
                storage = [:]
            }
        }
        
        // MARK: - Bookmark Manager
        public final class MockBookmarkManager: BookmarkManagerProtocol {
            private var error: Error?
            private(set) var createBookmarkCalled = false
            private(set) var resolveBookmarkCalled = false
            private(set) var lastBookmarkPath: String?
            private(set) var lastResolvedPath: String?
            private var bookmarks: [String: Data] = [:]
            
            public init() {}
            
            public func simulateError(_ error: Error?) {
                self.error = error
            }
            
            public func createBookmark(for path: String) throws -> Data {
                if let error = error { throw error }
                createBookmarkCalled = true
                lastBookmarkPath = path
                let bookmarkData = "mock_bookmark_\(path)".data(using: .utf8)!
                bookmarks[path] = bookmarkData
                return bookmarkData
            }
            
            public func resolveBookmark(_ bookmark: Data) throws -> String {
                if let error = error { throw error }
                resolveBookmarkCalled = true
                guard let path = bookmarks.first(where: { $0.value == bookmark })?.key else {
                    throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid bookmark"])
                }
                lastResolvedPath = path
                return path
            }
            
            public func reset() {
                error = nil
                createBookmarkCalled = false
                resolveBookmarkCalled = false
                lastBookmarkPath = nil
                lastResolvedPath = nil
                bookmarks.removeAll()
            }
        }
    }
}
