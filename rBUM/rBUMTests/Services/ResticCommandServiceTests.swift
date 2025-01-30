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
    // MARK: - Repository Initialization Tests
    
    @Test("Initialize repository with various configurations",
          .tags(.core, .integration, .security),
          arguments: [
              (path: "/test/path", password: "testPassword", keyFile: nil),
              (path: "/test/path2", password: "complex!@#$%^&*()", keyFile: nil),
              (path: "/test/secure", password: "testPass", keyFile: "key.txt")
          ])
    func testInitializeRepository(path: String, password: String, keyFile: String?) async throws {
        // Given
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let repositoryPath = URL(fileURLWithPath: path)
        
        processExecutor.output = "repository abc123 initialized"
        
        // When
        try await commandService.initializeRepository(
            at: repositoryPath,
            password: password,
            keyFile: keyFile
        )
        
        // Then
        #expect(processExecutor.lastCommand == "/opt/homebrew/bin/restic")
        #expect(processExecutor.lastArguments?.contains("init") == true)
        #expect(processExecutor.lastArguments?.contains("--json") == true)
        #expect(processExecutor.lastEnvironment?["RESTIC_PASSWORD"] == password)
        #expect(processExecutor.lastEnvironment?["RESTIC_REPOSITORY"] == path)
        if let keyFile = keyFile {
            #expect(processExecutor.lastArguments?.contains("--key-file") == true)
            #expect(processExecutor.lastArguments?.contains(keyFile) == true)
        }
    }
    
    // MARK: - Backup Tests
    
    @Test("Create backup with various configurations",
          .tags(.core, .integration, .backup),
          arguments: [
              (paths: ["/path1"], tags: ["test"]),
              (paths: ["/path1", "/path2"], tags: ["test", "backup"]),
              (paths: ["/path1", "/path2", "/path3"], tags: ["daily", "system"])
          ])
    func testCreateBackup(paths: [String], tags: [String]) async throws {
        // Given
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
        
        processExecutor.output = "snapshot abc123 saved"
        
        // When
        try await commandService.createBackup(
            paths: paths.map { URL(fileURLWithPath: $0) },
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
        paths.forEach { path in
            #expect(processExecutor.lastArguments?.contains(path) == true)
        }
        tags.forEach { tag in
            #expect(processExecutor.lastArguments?.contains("--tag") == true)
            #expect(processExecutor.lastArguments?.contains(tag) == true)
        }
    }
    
    @Test("Progress reporting with various backup states",
          .tags(.core, .integration, .backup))
    func testBackupProgress() async throws {
        // Given
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
        
        // Mock different progress states
        processExecutor.output = """
            {"message_type":"status","seconds_elapsed":1.2,"seconds_remaining":10,"bytes_done":1024,"total_bytes":10240,"files_done":5,"total_files":20,"current_file":"/path1/file1.txt"}
            {"message_type":"status","seconds_elapsed":2.4,"seconds_remaining":5,"bytes_done":5120,"total_bytes":10240,"files_done":10,"total_files":20,"current_file":"/path1/file2.txt"}
            {"message_type":"summary","total_bytes":10240,"total_files":20}
            """
        
        var progressUpdates: [BackupProgress] = []
        var statusChanges: [BackupStatus] = []
        
        // When
        try await commandService.createBackup(
            paths: [URL(fileURLWithPath: "/test/path")],
            to: repository,
            credentials: credentials,
            tags: ["test"],
            onProgress: { progressUpdates.append($0) },
            onStatusChange: { statusChanges.append($0) }
        )
        
        // Then
        #expect(progressUpdates.count >= 2)
        #expect(statusChanges.contains(where: { if case .preparing = $0 { true } else { false } }))
        #expect(statusChanges.contains(where: { if case .backing = $0 { true } else { false } }))
        #expect(statusChanges.contains(where: { if case .completed = $0 { true } else { false } }))
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle various error scenarios",
          .tags(.core, .integration, .error_handling),
          arguments: [
              (errorCode: 1, errorMessage: "repository not initialized", expectedError: ResticError.repositoryNotInitialized),
              (errorCode: 1, errorMessage: "wrong password", expectedError: ResticError.authenticationFailed),
              (errorCode: 1, errorMessage: "lock already held", expectedError: ResticError.repositoryLocked),
              (errorCode: 1, errorMessage: "unknown error", expectedError: ResticError.commandFailed("unknown error"))
          ])
    func testErrorHandling(errorCode: Int32, errorMessage: String, expectedError: ResticError) async throws {
        // Given
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        processExecutor.error = errorMessage
        processExecutor.exitCode = errorCode
        
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let path = URL(fileURLWithPath: "/test/path")
        
        // When/Then
        await #expect(throws: expectedError) {
            try await commandService.initializeRepository(at: path, password: "test")
        }
    }
}
