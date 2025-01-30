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
    
    func execute(command: String, arguments: [String], environment: [String: String]?) async throws -> ProcessResult {
        if shouldThrowError {
            throw ProcessError.executionFailed(error)
        }
        lastCommand = command
        lastArguments = arguments
        lastEnvironment = environment
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
        let password = "testPassword"
        processExecutor.output = "repository initialized"
        
        // When
        try await commandService.initializeRepository(at: path, password: password)
        
        // Then
        #expect(processExecutor.lastCommand == "/opt/homebrew/bin/restic")
        #expect(processExecutor.lastArguments == ["init"])
        #expect(processExecutor.lastEnvironment?["RESTIC_PASSWORD"] == password)
        #expect(processExecutor.lastEnvironment?["RESTIC_REPOSITORY"] == path.path)
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
        try await commandService.createBackup(paths: paths, to: repository, credentials: credentials, tags: tags)
        
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
