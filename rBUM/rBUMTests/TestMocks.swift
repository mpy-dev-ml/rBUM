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
    /// Namespace for all mock implementations
    public enum TestMocks {
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
            
            func encrypt(_ data: Data) throws -> Data {
                if let error = error { throw error }
                encryptCalled = true
                return data
            }
            
            func decrypt(_ data: Data) throws -> Data {
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
            var error: Error?
            var createDirectoryCalled = false
            var removeItemCalled = false
            var fileExistsCalled = false
            var writeDataCalled = false
            var readDataCalled = false
            var files: [String: Data] = [:]
            var directories: Set<String> = []
            
            func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws {
                if let error = error { throw error }
                createDirectoryCalled = true
                directories.insert(url.path)
            }
            
            func removeItem(at url: URL) throws {
                if let error = error { throw error }
                removeItemCalled = true
                files.removeValue(forKey: url.path)
                directories.remove(url.path)
            }
            
            func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
                fileExistsCalled = true
                return files[path] != nil || directories.contains(path)
            }
            
            func write(_ data: Data, to url: URL) throws {
                if let error = error { throw error }
                writeDataCalled = true
                files[url.path] = data
            }
            
            func contents(atPath path: String) -> Data? {
                readDataCalled = true
                return files[path]
            }
            
            func reset() {
                error = nil
                createDirectoryCalled = false
                removeItemCalled = false
                fileExistsCalled = false
                writeDataCalled = false
                readDataCalled = false
                files = [:]
                directories = []
            }
        }
        
        // MARK: - Notification Center
        public final class MockNotificationCenter: NotificationCenter {
            var postNotificationCalled = false
            var lastNotification: Notification?
            var lastName: NSNotification.Name?
            var lastObject: Any?
            var lastUserInfo: [AnyHashable: Any]?
            
            override func post(_ notification: Notification) {
                postNotificationCalled = true
                lastNotification = notification
            }
            
            override func post(name aName: NSNotification.Name, object anObject: Any?) {
                postNotificationCalled = true
                lastName = aName
                lastObject = anObject
            }
            
            override func post(name aName: NSNotification.Name, object anObject: Any?, userInfo aUserInfo: [AnyHashable : Any]?) {
                postNotificationCalled = true
                lastName = aName
                lastObject = anObject
                lastUserInfo = aUserInfo
            }
            
            func reset() {
                postNotificationCalled = false
                lastNotification = nil
                lastName = nil
                lastObject = nil
                lastUserInfo = nil
            }
        }
        
        // MARK: - Date Provider
        public final class MockDateProvider: DateProviderProtocol {
            var currentDate: Date = Date()
            
            func now() -> Date {
                return currentDate
            }
            
            func reset() {
                currentDate = Date()
            }
        }
        
        // MARK: - Progress Tracker
        public final class MockProgressTracker: ProgressTrackerProtocol {
            var progress: Double = 0
            var isTracking = false
            
            func startTracking() {
                isTracking = true
            }
            
            func stopTracking() {
                isTracking = false
            }
            
            func updateProgress(_ value: Double) {
                progress = value
            }
            
            func reset() {
                progress = 0
                isTracking = false
            }
        }
        
        // MARK: - Repository Creation Service
        public final class MockRepositoryCreationService: RepositoryCreationServiceProtocol {
            var createResult: Repository?
            var importResult: Repository?
            var createError: Error?
            var importError: Error?
            
            func createRepository(name: String, path: URL, password: String) async throws -> Repository {
                if let error = createError {
                    throw error
                }
                return createResult ?? Repository(name: name, path: path)
            }
            
            func importRepository(name: String, path: URL, password: String) async throws -> Repository {
                if let error = importError {
                    throw error
                }
                return importResult ?? Repository(name: name, path: path)
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
    }
}
