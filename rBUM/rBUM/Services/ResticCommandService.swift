//
//  ResticCommandService.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation

enum ResticError: Error {
    case commandFailed(String)
    case invalidRepository
    case invalidPassword
    case repositoryNotFound
    case backupFailed(String)
    case restoreFailed(String)
    case credentialsNotFound
}

/// Protocol defining the ResticCommandService interface
protocol ResticCommandServiceProtocol {
    func initializeRepository(_ repository: Repository, password: String) async throws
    func checkRepository(_ repository: Repository) async throws -> Bool
    func createBackup(for repository: Repository, paths: [String]) async throws
}

/// Service for executing Restic commands
final class ResticCommandService: ResticCommandServiceProtocol {
    private let fileManager = FileManager.default
    private let resticPath: String
    private let credentialsManager: CredentialsManagerProtocol
    private let processExecutor: ProcessExecutorProtocol
    
    init(credentialsManager: CredentialsManagerProtocol, processExecutor: ProcessExecutorProtocol) {
        // TODO: Make this configurable in settings
        self.resticPath = "restic"
        self.credentialsManager = credentialsManager
        self.processExecutor = processExecutor
    }
    
    @discardableResult
    private func executeCommand(_ arguments: [String], password: String? = nil, repository: Repository? = nil) async throws -> String {
        var environment: [String: String] = [:]
        if let password = password {
            environment["RESTIC_PASSWORD"] = password
        }
        if let repository = repository {
            environment["RESTIC_REPOSITORY"] = repository.path.path
        }
        
        let result = try await processExecutor.execute(command: resticPath, arguments: arguments, environment: environment)
        
        if result.exitCode != 0 {
            throw ResticError.commandFailed(result.error)
        }
        
        return result.output
    }
    
    func initializeRepository(_ repository: Repository, password: String) async throws {
        let arguments = ["init"]
        try await executeCommand(arguments, password: password, repository: repository)
        try await credentialsManager.storeCredentials(password, for: repository.credentials)
    }
    
    func checkRepository(_ repository: Repository) async throws -> Bool {
        let password = try await credentialsManager.retrievePassword(for: repository.credentials)
        
        let arguments = ["check"]
        do {
            _ = try await executeCommand(arguments, password: password, repository: repository)
            return true
        } catch ResticError.commandFailed {
            return false
        }
    }
    
    func createBackup(for repository: Repository, paths: [String]) async throws {
        let password = try await credentialsManager.retrievePassword(for: repository.credentials)
        
        var arguments = ["backup", "--json"]
        arguments.append(contentsOf: paths)
        
        try await executeCommand(arguments, password: password, repository: repository)
    }
}
