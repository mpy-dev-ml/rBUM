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
    var password: String?
    var shouldThrowError = false
    
    func storeCredentials(_ password: String, for credentials: RepositoryCredentials) async throws {
        if shouldThrowError { throw KeychainError.unexpectedStatus(-1) }
        self.password = password
    }
    
    func retrievePassword(for credentials: RepositoryCredentials) async throws -> String {
        if shouldThrowError { throw KeychainError.unexpectedStatus(-1) }
        guard let password = password else {
            throw KeychainError.itemNotFound
        }
        return password
    }
    
    func updatePassword(_ password: String, for credentials: RepositoryCredentials) async throws {
        if shouldThrowError { throw KeychainError.unexpectedStatus(-1) }
        guard self.password != nil else {
            throw KeychainError.itemNotFound
        }
        self.password = password
    }
    
    func deleteCredentials(_ credentials: RepositoryCredentials) async throws {
        if shouldThrowError { throw KeychainError.unexpectedStatus(-1) }
        guard password != nil else {
            throw KeychainError.itemNotFound
        }
        password = nil
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
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // Given
        let password = "testPassword"
        processExecutor.output = "repository initialized"
        
        // When
        try await commandService.initializeRepository(repository, password: password)
        
        // Then
        #expect(processExecutor.lastCommand == "restic")
        #expect(processExecutor.lastArguments == ["init"])
        #expect(processExecutor.lastEnvironment?["RESTIC_PASSWORD"] == password)
        #expect(processExecutor.lastEnvironment?["RESTIC_REPOSITORY"] == repository.path.path)
    }
    
    @Test("Check repository")
    func testCheckRepository() async throws {
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // Given
        let password = "testPassword"
        credentialsManager.password = password
        processExecutor.output = "repository is healthy"
        
        // When
        let result = try await commandService.checkRepository(repository)
        
        // Then
        #expect(result == true)
        #expect(processExecutor.lastCommand == "restic")
        #expect(processExecutor.lastArguments == ["check"])
        #expect(processExecutor.lastEnvironment?["RESTIC_PASSWORD"] == password)
        #expect(processExecutor.lastEnvironment?["RESTIC_REPOSITORY"] == repository.path.path)
    }
    
    @Test("Create backup")
    func testCreateBackup() async throws {
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // Given
        let password = "testPassword"
        let paths = ["/path1", "/path2"]
        credentialsManager.password = password
        processExecutor.output = "snapshot abc123 saved"
        
        // When
        try await commandService.createBackup(for: repository, paths: paths)
        
        // Then
        #expect(processExecutor.lastCommand == "restic")
        #expect(processExecutor.lastArguments == ["backup", "--json", "/path1", "/path2"])
        #expect(processExecutor.lastEnvironment?["RESTIC_PASSWORD"] == password)
        #expect(processExecutor.lastEnvironment?["RESTIC_REPOSITORY"] == repository.path.path)
    }
    
    @Test("Handle process execution errors")
    func testProcessExecutionError() async throws {
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // Given
        let password = "testPassword"
        credentialsManager.password = password
        processExecutor.shouldThrowError = true
        processExecutor.error = "Mock error"
        
        // When/Then
        await #expect(throws: ProcessError.executionFailed("Mock error")) {
            try await commandService.checkRepository(repository)
        }
    }
    
    @Test("Handle missing credentials")
    func testMissingCredentials() async throws {
        let credentialsManager = MockCredentialsManager()
        let processExecutor = MockProcessExecutor()
        let commandService = ResticCommandService(credentialsManager: credentialsManager, processExecutor: processExecutor)
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        // When/Then
        await #expect(throws: KeychainError.itemNotFound) {
            try await commandService.checkRepository(repository)
        }
    }
}
