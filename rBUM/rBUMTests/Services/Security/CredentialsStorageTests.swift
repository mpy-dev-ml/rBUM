//
//  CredentialsStorageTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

/// Mock FileManager for testing CredentialsStorage
final class MockFileManager: FileManager {
    private let testDirectory: URL
    private var files: [String: Data] = [:]
    private var isDirectoryOverrides: [String: Bool] = [:]
    private let queue = DispatchQueue(label: "com.mpy.rBUM.MockFileManager", attributes: .concurrent)
    private var shouldFailNextOperation = false
    private var operationError: Error?
    private var shouldFailDirectoryCreation = false
    private var shouldFailFileOperations = false
    
    init(testDirectory: URL) {
        self.testDirectory = testDirectory
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func urls(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask) -> [URL] {
        // Always return our test directory for application support
        if directory == .applicationSupportDirectory {
            return [testDirectory]
        }
        return super.urls(for: directory, in: domain)
    }
    
    override func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) throws {
        try queue.sync(flags: .barrier) {
            if shouldFailNextOperation {
                shouldFailNextOperation = false
                if let error = operationError {
                    throw error
                }
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [
                    NSFilePathErrorKey: url.path
                ])
            }
            
            if shouldFailDirectoryCreation {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [
                    NSFilePathErrorKey: url.path
                ])
            }
            
            // Mark this as a directory
            isDirectoryOverrides[url.path] = true
            
            // If we need to create intermediate directories
            if withIntermediateDirectories {
                let pathComponents = url.pathComponents
                var currentPath = ""
                for component in pathComponents {
                    currentPath += "/" + component
                    isDirectoryOverrides[currentPath] = true
                }
            }
        }
    }
    
    override func removeItem(at url: URL) throws {
        try queue.sync(flags: .barrier) {
            if shouldFailNextOperation {
                shouldFailNextOperation = false
                if let error = operationError {
                    throw error
                }
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [
                    NSFilePathErrorKey: url.path
                ])
            }
            
            if shouldFailFileOperations {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [
                    NSFilePathErrorKey: url.path,
                    NSLocalizedDescriptionKey: "Failed to remove file: Permission denied"
                ])
            }
            
            let path = url.path
            if !files.keys.contains(where: { $0.hasPrefix(path) }) {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: [
                    NSFilePathErrorKey: path
                ])
            }
            // Remove all files under this path
            files = files.filter { !$0.key.hasPrefix(path) }
            isDirectoryOverrides.removeValue(forKey: path)
        }
    }
    
    override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        queue.sync {
            if let isDir = isDirectoryOverrides[path] {
                isDirectory?.pointee = ObjCBool(isDir)
                return true
            }
            
            if files[path] != nil {
                isDirectory?.pointee = ObjCBool(false)
                return true
            }
            
            return false
        }
    }
    
    override func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions = []) throws -> [URL] {
        try queue.sync {
            if shouldFailNextOperation {
                shouldFailNextOperation = false
                if let error = operationError {
                    throw error
                }
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: [
                    NSFilePathErrorKey: url.path
                ])
            }
            
            if shouldFailFileOperations {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: [
                    NSFilePathErrorKey: url.path,
                    NSLocalizedDescriptionKey: "Failed to read directory: Permission denied"
                ])
            }
            
            // Check if this is actually a directory
            if isDirectoryOverrides[url.path] != true {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: [
                    NSFilePathErrorKey: url.path
                ])
            }
            
            // Find all files and directories that are direct children of this URL
            let urlPath = url.path
            var contents: [URL] = []
            
            // Add files
            for filePath in files.keys {
                let fileURL = URL(fileURLWithPath: filePath)
                if fileURL.deletingLastPathComponent().path == urlPath {
                    contents.append(fileURL)
                }
            }
            
            // Add directories
            for dirPath in isDirectoryOverrides.keys {
                let dirURL = URL(fileURLWithPath: dirPath)
                if dirURL.deletingLastPathComponent().path == urlPath {
                    contents.append(dirURL)
                }
            }
            
            return contents
        }
    }
    
    override func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]? = nil) -> Bool {
        queue.sync(flags: .barrier) {
            if shouldFailNextOperation {
                shouldFailNextOperation = false
                return false
            }
            
            if shouldFailFileOperations {
                return false
            }
            
            guard let data = data else { return false }
            files[path] = data
            isDirectoryOverrides[path] = false
            return true
        }
    }
    
    func write(_ data: Data, to url: URL, options: Data.WritingOptions = []) throws {
        try queue.sync(flags: .barrier) {
            if shouldFailNextOperation {
                shouldFailNextOperation = false
                if let error = operationError {
                    throw error
                }
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [
                    NSFilePathErrorKey: url.path
                ])
            }
            
            if shouldFailFileOperations {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [
                    NSFilePathErrorKey: url.path
                ])
            }
            
            // Store the data in our in-memory dictionary
            files[url.path] = data
        }
    }
    
    override func contents(atPath path: String) -> Data? {
        queue.sync {
            if shouldFailNextOperation {
                shouldFailNextOperation = false
                return nil
            }
            
            if shouldFailFileOperations {
                return nil
            }
            
            return files[path]
        }
    }
    
    // Helper method to inject corrupted file for testing
    func injectCorruptedFile(named filename: String, in directory: URL) {
        queue.sync(flags: .barrier) {
            let path = directory.appendingPathComponent(filename).path
            files[path] = "{ invalid json }".data(using: .utf8)!
            isDirectoryOverrides[path] = false
        }
    }
    
    // Helper method to create a file at the directory path
    func createFileAtDirectoryPath(_ directory: URL) {
        queue.sync(flags: .barrier) {
            let path = directory.path
            files[path] = "Not a directory".data(using: .utf8)!
            isDirectoryOverrides[path] = false
        }
    }
    
    // Helper method to simulate file system errors
    func simulateError(_ error: Error? = nil) {
        queue.sync(flags: .barrier) {
            shouldFailNextOperation = true
            operationError = error
        }
    }
    
    // Helper method to simulate directory creation failure
    func simulateDirectoryCreationFailure() {
        queue.sync(flags: .barrier) {
            shouldFailDirectoryCreation = true
        }
    }
    
    // Helper method to simulate file operation failures
    func simulateFileOperationFailure() {
        queue.sync(flags: .barrier) {
            shouldFailFileOperations = true
        }
    }
}

struct CredentialsStorageTests {
    // Root directory for all test files
    private static let rootTestDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("dev.mpy.rBUM.tests", isDirectory: true)
    
    // MARK: - Test Setup
    
    static func createTestStorage() throws -> (CredentialsStorage, URL, MockFileManager) {
        // Create test directory with unique UUID
        let testDir = rootTestDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let credentialsDir = testDir.appendingPathComponent("dev.mpy.rBUM/credentials", isDirectory: true)
        
        // Create a mock FileManager that uses our test directory
        let mockFileManager = MockFileManager(testDirectory: testDir)
        let storage = CredentialsStorage(testDirectory: credentialsDir, fileManager: mockFileManager)
        
        return (storage, testDir, mockFileManager)
    }
    
    static func cleanupTestStorage(_ directory: URL) throws {
        // Nothing to clean up since we're using an in-memory MockFileManager
    }
    
    // MARK: - Basic Operations Tests
    
    @Test("Store and retrieve credentials successfully", tags: ["basic", "storage"])
    func testStoreAndRetrieveCredentials() throws {
        let (storage, directory, _) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "test-password",
            repositoryPath: "/test/path"
        )
        
        // Store credentials
        try storage.store(credentials)
        
        // Retrieve credentials
        let retrieved = try storage.retrieve(forRepositoryId: credentials.repositoryId)
        #expect(retrieved != nil)
        #expect(retrieved?.repositoryId == credentials.repositoryId)
        #expect(retrieved?.repositoryPath == credentials.repositoryPath)
        
        // Verify only one entry exists
        let allCredentials = try storage.list()
        #expect(allCredentials.count == 1)
    }
    
    @Test("Update existing credentials", tags: ["basic", "storage"])
    func testUpdateCredentials() throws {
        let (storage, directory, _) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let id = UUID()
        let credentials = RepositoryCredentials(
            repositoryId: id,
            password: "test-password",
            repositoryPath: "/test/path"
        )
        
        // Store initial credentials
        try storage.store(credentials)
        
        // Create updated credentials with same ID
        let updatedCredentials = RepositoryCredentials(
            repositoryId: id,
            password: "new-password",
            repositoryPath: "/new/path"
        )
        
        // Update credentials
        try storage.update(updatedCredentials)
        
        // Verify update
        let retrieved = try storage.retrieve(forRepositoryId: id)
        #expect(retrieved != nil)
        #expect(retrieved?.repositoryPath == "/new/path")
        
        // Verify only one entry exists
        let allCredentials = try storage.list()
        #expect(allCredentials.count == 1)
    }
    
    @Test("Delete credentials successfully", tags: ["basic", "storage"])
    func testDeleteCredentials() throws {
        let (storage, directory, _) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "test-password",
            repositoryPath: "/test/path"
        )
        
        // Store credentials
        try storage.store(credentials)
        
        // Delete credentials
        try storage.delete(forRepositoryId: credentials.repositoryId)
        
        // Verify deletion
        let retrieved = try storage.retrieve(forRepositoryId: credentials.repositoryId)
        #expect(retrieved == nil)
        
        let allCredentials = try storage.list()
        #expect(allCredentials.isEmpty)
    }
    
    // MARK: - List Operations Tests
    
    @Test("List multiple credentials", tags: ["list", "storage"])
    func testListCredentials() throws {
        let (storage, directory, _) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let credentials1 = RepositoryCredentials(
            repositoryId: UUID(),
            password: "test-password1",
            repositoryPath: "/test/path1"
        )
        
        let credentials2 = RepositoryCredentials(
            repositoryId: UUID(),
            password: "test-password2",
            repositoryPath: "/test/path2"
        )
        
        // Store multiple credentials
        try storage.store(credentials1)
        try storage.store(credentials2)
        
        // List all credentials
        let allCredentials = try storage.list()
        #expect(allCredentials.count == 2)
        #expect(allCredentials.contains { $0.repositoryPath == "/test/path1" })
        #expect(allCredentials.contains { $0.repositoryPath == "/test/path2" })
    }
    
    @Test("Empty storage returns empty array", tags: ["list", "storage"])
    func testEmptyStorageReturnsEmptyArray() throws {
        let (storage, directory, _) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let credentials = try storage.list()
        #expect(credentials.isEmpty)
    }
    
    // MARK: - Security Tests
    
    @Test("Handle corrupted credential files", tags: ["security", "storage"])
    func testHandleCorruptedFiles() throws {
        let (storage, directory, fileManager) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "test-password",
            repositoryPath: "/test/path"
        )
        
        // Store valid credentials
        try storage.store(credentials)
        
        // Inject corrupted file
        fileManager.injectCorruptedFile(
            named: "corrupted.json",
            in: directory.appendingPathComponent("dev.mpy.rBUM/credentials")
        )
        
        // List should succeed but ignore corrupted file
        let allCredentials = try storage.list()
        #expect(allCredentials.count == 1)
        #expect(allCredentials.first?.repositoryId == credentials.repositoryId)
    }
    
    @Test("Prevent password leakage in errors", tags: ["security", "storage"])
    func testPreventPasswordLeakage() throws {
        let (storage, directory, fileManager) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "sensitive-password",
            repositoryPath: "/test/path"
        )
        
        // Simulate error during storage
        fileManager.simulateError()
        var thrownError: Error?
        do {
            try storage.store(credentials)
        } catch {
            thrownError = error
        }
        
        // Verify error message doesn't contain password
        #expect(thrownError != nil)
        let errorDescription = String(describing: thrownError)
        #expect(!errorDescription.contains("sensitive-password"))
    }
    
    @Test("Handle concurrent access safely", tags: ["security", "concurrency"])
    func testConcurrentAccess() throws {
        let (storage, directory, _) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        // Create multiple credentials
        let credentials = (0..<10).map { i in
            RepositoryCredentials(
                repositoryId: UUID(),
                password: "test-password\(i)",
                repositoryPath: "/test/path\(i)"
            )
        }
        
        // Concurrently store and retrieve credentials
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.mpy.rBUM.test", attributes: .concurrent)
        var errors: [Error] = []
        
        // Store credentials concurrently
        for credential in credentials {
            group.enter()
            queue.async {
                do {
                    try storage.store(credential)
                } catch {
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        // Wait for all stores to complete
        group.wait()
        
        // Check if any errors occurred
        #expect(errors.isEmpty)
        
        // List all credentials
        let allCredentials = try storage.list()
        #expect(allCredentials.count == credentials.count)
        
        // Verify all credentials were stored correctly
        for credential in credentials {
            let retrieved = try storage.retrieve(forRepositoryId: credential.repositoryId)
            #expect(retrieved != nil)
            #expect(retrieved?.repositoryId == credential.repositoryId)
            #expect(retrieved?.repositoryPath == credential.repositoryPath)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle file system errors", tags: ["error", "storage"])
    func testHandleFileSystemErrors() throws {
        let (storage, directory, fileManager) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "test-password",
            repositoryPath: "/test/path"
        )
        
        // Test store error
        fileManager.simulateError()
        var thrownError: Error?
        do {
            try storage.store(credentials)
        } catch {
            thrownError = error
        }
        #expect(thrownError != nil)
        
        // Test retrieve error
        fileManager.simulateError()
        thrownError = nil
        do {
            _ = try storage.retrieve(forRepositoryId: credentials.repositoryId)
        } catch {
            thrownError = error
        }
        #expect(thrownError != nil)
        
        // Test list error
        fileManager.simulateError()
        thrownError = nil
        do {
            _ = try storage.list()
        } catch {
            thrownError = error
        }
        #expect(thrownError != nil)
        
        // Test delete error
        fileManager.simulateError()
        thrownError = nil
        do {
            try storage.delete(forRepositoryId: credentials.repositoryId)
        } catch {
            thrownError = error
        }
        #expect(thrownError != nil)
        
        // Test custom error
        let customError = NSError(domain: "com.mpy.rBUM.test", code: 42, userInfo: nil)
        fileManager.simulateError(customError)
        thrownError = nil
        do {
            try storage.store(credentials)
        } catch {
            thrownError = error
        }
        #expect(thrownError as NSError? == customError)
    }
    
    @Test("Handle directory creation failure", tags: ["error", "storage"])
    func testHandleDirectoryCreationFailure() throws {
        let (storage, directory, fileManager) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "test-password",
            repositoryPath: "/test/path"
        )
        
        // Simulate directory creation failure
        fileManager.simulateDirectoryCreationFailure()
        
        // Attempt to store credentials
        var thrownError: Error?
        do {
            try storage.store(credentials)
        } catch {
            thrownError = error
        }
        
        // Verify error was thrown
        #expect(thrownError != nil)
        if let error = thrownError as NSError? {
            #expect(error.domain == NSCocoaErrorDomain)
            #expect(error.code == NSFileWriteNoPermissionError)
            #expect(error.userInfo[NSLocalizedDescriptionKey] as? String == "Failed to create directory: Permission denied")
        }
    }
    
    @Test("Handle file operation failures", tags: ["error", "storage"])
    func testHandleFileOperationFailures() throws {
        let (storage, directory, fileManager) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "test-password",
            repositoryPath: "/test/path"
        )
        
        // Store initial credentials
        try storage.store(credentials)
        
        // Simulate file operation failures
        fileManager.simulateFileOperationFailure()
        
        // Test read failure
        var thrownError: Error?
        do {
            _ = try storage.retrieve(forRepositoryId: credentials.repositoryId)
        } catch {
            thrownError = error
        }
        #expect(thrownError != nil)
        if let error = thrownError as NSError? {
            #expect(error.domain == NSCocoaErrorDomain)
            #expect(error.code == NSFileReadNoPermissionError)
        }
        
        // Test write failure
        thrownError = nil
        do {
            try storage.store(credentials)
        } catch {
            thrownError = error
        }
        #expect(thrownError != nil)
        if let error = thrownError as NSError? {
            #expect(error.domain == NSCocoaErrorDomain)
            #expect(error.code == NSFileWriteNoPermissionError)
            #expect(error.userInfo[NSLocalizedDescriptionKey] as? String == "Failed to write file: Permission denied")
        }
        
        // Test delete failure
        thrownError = nil
        do {
            try storage.delete(forRepositoryId: credentials.repositoryId)
        } catch {
            thrownError = error
        }
        #expect(thrownError != nil)
        if let error = thrownError as NSError? {
            #expect(error.domain == NSCocoaErrorDomain)
            #expect(error.code == NSFileWriteNoPermissionError)
            #expect(error.userInfo[NSLocalizedDescriptionKey] as? String == "Failed to remove file: Permission denied")
        }
        
        // Test list failure
        thrownError = nil
        do {
            _ = try storage.list()
        } catch {
            thrownError = error
        }
        #expect(thrownError != nil)
        if let error = thrownError as NSError? {
            #expect(error.domain == NSCocoaErrorDomain)
            #expect(error.code == NSFileReadNoPermissionError)
            #expect(error.userInfo[NSLocalizedDescriptionKey] as? String == "Failed to read directory: Permission denied")
        }
    }
    
    // MARK: - Parameterized Tests
    
    @Test("Handle various credential formats", tags: ["parameterized", "storage"])
    func testCredentialFormats() throws {
        let (storage, directory, _) = try Self.createTestStorage()
        defer { try? Self.cleanupTestStorage(directory) }
        
        let testCases = [
            (UUID(), "simple-password", "/path/to/repo"),
            (UUID(), "password with spaces", "/path/with spaces/repo"),
            (UUID(), "password!@#$%^&*()", "/path/with/special/chars/!@#$/repo"),
            (UUID(), String(repeating: "a", count: 1000), "/very/long/path/" + String(repeating: "a", count: 1000)),
            (UUID(), "", "/empty/password/repo"),
            (UUID(), "password", "")
        ]
        
        for (id, password, path) in testCases {
            let credentials = RepositoryCredentials(
                repositoryId: id,
                password: password,
                repositoryPath: path
            )
            
            // Store credentials
            try storage.store(credentials)
            
            // Retrieve and verify
            let retrieved = try storage.retrieve(forRepositoryId: id)
            #expect(retrieved != nil)
            #expect(retrieved?.repositoryId == id)
            #expect(retrieved?.password == password)
            #expect(retrieved?.repositoryPath == path)
            
            // Clean up
            try storage.delete(forRepositoryId: id)
        }
    }
}
