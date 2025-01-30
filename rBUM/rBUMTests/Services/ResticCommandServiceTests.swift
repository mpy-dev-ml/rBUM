//
//  ResticCommandServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Security
import Foundation
@testable import rBUM

/// Mock implementation of KeychainCredentialsManager for testing
final class MockCredentialsManager: CredentialsManagerProtocol {
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

/// Mock implementation of ProcessExecutor for testing
final class MockProcessExecutor: ProcessExecutorProtocol {
    var output: String = ""
    var error: String = ""
    var exitCode: Int32 = 0
    var shouldThrowError = false
    var lastCommand: String?
    var lastArguments: [String]?
    var lastEnvironment: [String: String]?
    
    func execute(
        command: String,
        arguments: [String],
        environment: [String: String]?,
        onOutput: ((String) -> Void)?
    ) async throws -> ProcessResult {
        if shouldThrowError {
            throw ProcessError.executionFailed(error)
        }
        lastCommand = command
        lastArguments = arguments
        lastEnvironment = environment
        
        // If we have an output callback, simulate streaming output
        if let onOutput = onOutput {
            output.split(separator: "\n").forEach { line in
                onOutput(String(line))
            }
        }
        
        return ProcessResult(output: output, error: error, exitCode: exitCode)
    }
}

struct ResticCommandServiceTests {
    @Test("Initialize repository")
    func testInitializeRepository() async throws {
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let path = URL(fileURLWithPath: "/test/path")
        
        // Given
        processExecutor.output = "repository abc123 initialized"
        
        // When
        try await commandService.initializeRepository(at: path, password: "testPassword")
        
        // Then
        #expect(processExecutor.lastCommand == "/opt/homebrew/bin/restic")
        #expect(processExecutor.lastArguments?.contains("init") == true)
        #expect(processExecutor.lastArguments?.contains("--json") == true)
        #expect(processExecutor.lastEnvironment?["RESTIC_PASSWORD"] == "testPassword")
        #expect(processExecutor.lastEnvironment?["RESTIC_REPOSITORY"] == path.path)
    }
    
    @Test("Create backup")
    func testCreateBackup() async throws {
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let repository = Repository(
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        let credentials = RepositoryCredentials(
            repositoryId: repository.id,
            password: "testPassword",
            repositoryPath: repository.path.path
        )
        
        // Given
        let paths = [URL(fileURLWithPath: "/path1"), URL(fileURLWithPath: "/path2")]
        let tags = ["test", "backup"]
        processExecutor.output = "snapshot abc123 saved"
        
        // When
        try await commandService.createBackup(
            paths: paths,
            to: repository,
            credentials: credentials,
            tags: tags,
            onProgress: { _ in },
            onStatusChange: { _ in }
        )
        
        // Then
        #expect(processExecutor.lastCommand == "/opt/homebrew/bin/restic")
        #expect(processExecutor.lastArguments?.contains("backup") == true)
        #expect(processExecutor.lastArguments?.contains("--json") == true)
        #expect(processExecutor.lastArguments?.contains("--verbose") == true)
        #expect(processExecutor.lastArguments?.contains("/path1") == true)
        #expect(processExecutor.lastArguments?.contains("/path2") == true)
        #expect(processExecutor.lastEnvironment?["RESTIC_PASSWORD"] == credentials.password)
        #expect(processExecutor.lastEnvironment?["RESTIC_REPOSITORY"] == credentials.repositoryPath)
    }
    
    @Test("Create backup with progress reporting")
    func testCreateBackupWithProgress() async throws {
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let repository = Repository(
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        let credentials = RepositoryCredentials(
            repositoryId: repository.id,
            password: "testPassword",
            repositoryPath: repository.path.path
        )
        
        // Given
        let paths = [URL(fileURLWithPath: "/path1"), URL(fileURLWithPath: "/path2")]
        let tags = ["test", "backup"]
        
        // Mock restic JSON output for progress
        processExecutor.output = """
            {"message_type":"status","seconds_elapsed":1.2,"seconds_remaining":10,"bytes_done":1024,"total_bytes":10240,"files_done":5,"total_files":20,"current_file":"/path1/file1.txt"}
            {"message_type":"status","seconds_elapsed":2.4,"seconds_remaining":5,"bytes_done":5120,"total_bytes":10240,"files_done":10,"total_files":20,"current_file":"/path1/file2.txt"}
            {"message_type":"summary","total_bytes":10240,"total_files":20}
            """
        
        var progressUpdates: [BackupProgress] = []
        var statusChanges: [BackupStatus] = []
        
        // When
        try await commandService.createBackup(
            paths: paths,
            to: repository,
            credentials: credentials,
            tags: tags,
            onProgress: { progress in
                progressUpdates.append(progress)
            },
            onStatusChange: { status in
                statusChanges.append(status)
            }
        )
        
        // Then
        #expect(progressUpdates.count == 2)
        #expect(statusChanges.count >= 3)  // preparing, backing, completed
        
        // Verify first progress update
        let firstProgress = progressUpdates[0]
        #expect(firstProgress.totalFiles == 20)
        #expect(firstProgress.processedFiles == 5)
        #expect(firstProgress.totalBytes == 10240)
        #expect(firstProgress.processedBytes == 1024)
        #expect(firstProgress.currentFile == "/path1/file1.txt")
        #expect(firstProgress.estimatedSecondsRemaining == 10)
        
        // Verify second progress update
        let secondProgress = progressUpdates[1]
        #expect(secondProgress.totalFiles == 20)
        #expect(secondProgress.processedFiles == 10)
        #expect(secondProgress.totalBytes == 10240)
        #expect(secondProgress.processedBytes == 5120)
        #expect(secondProgress.currentFile == "/path1/file2.txt")
        #expect(secondProgress.estimatedSecondsRemaining == 5)
        
        // Verify status transitions
        #expect(statusChanges[0] == .preparing)
        
        // Verify second status is .backing
        if case .backing(let progress) = statusChanges[1] {
            #expect(progress.totalFiles == 20)
            #expect(progress.processedFiles >= 5)
        } else {
            #expect(Bool(false), "Expected second status to be .backing, but got \(statusChanges[1])")
        }
        
        #expect(statusChanges.last == .completed)
    }
    
    @Test("Check repository")
    func testCheckRepository() async throws {
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let path = URL(fileURLWithPath: "/test/path")
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "testPassword",
            repositoryPath: path.path
        )
        
        // Given
        processExecutor.output = "repository is healthy"
        
        // When
        try await commandService.checkRepository(at: path, credentials: credentials)
        
        // Then
        #expect(processExecutor.lastCommand == "/opt/homebrew/bin/restic")
        #expect(processExecutor.lastArguments == ["check"])
        #expect(processExecutor.lastEnvironment?["RESTIC_PASSWORD"] == credentials.password)
        #expect(processExecutor.lastEnvironment?["RESTIC_REPOSITORY"] == credentials.repositoryPath)
    }
    
    @Test("Handle process execution errors")
    func testProcessExecutionError() async throws {
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let path = URL(fileURLWithPath: "/test/path")
        let credentials = RepositoryCredentials(
            repositoryId: UUID(),
            password: "testPassword",
            repositoryPath: path.path
        )
        
        // Given
        processExecutor.shouldThrowError = true
        processExecutor.error = "Mock error"
        
        // When/Then
        await #expect(throws: ProcessError.executionFailed("Mock error")) {
            try await commandService.checkRepository(at: path, credentials: credentials)
        }
    }
}
