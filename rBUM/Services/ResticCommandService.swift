//
//  ResticCommandService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Core
import Foundation

/// Service for executing Restic commands via XPC
public final class ResticCommandService: BaseSandboxedService, ResticServiceProtocol, HealthCheckable, Measurable {
    // MARK: - Properties

    private let xpcService: ResticXPCServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let operationQueue: OperationQueue
    private var activeOperations: Set<UUID> = []
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.resticCommand", attributes: .concurrent)

    public var isHealthy: Bool {
        // Check if we have any stuck operations
        accessQueue.sync {
            activeOperations.isEmpty
        }
    }

    // MARK: - Initialization

    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        xpcService: ResticXPCServiceProtocol,
        keychainService: KeychainServiceProtocol
    ) {
        self.xpcService = xpcService
        self.keychainService = keychainService

        operationQueue = OperationQueue()
        operationQueue.name = "dev.mpy.rBUM.resticQueue"
        operationQueue.maxConcurrentOperationCount = 1

        super.init(logger: logger, securityService: securityService)
    }

    // MARK: - ResticServiceProtocol Implementation

    public func initializeRepository(at url: URL) async throws {
        try await handleResticCommand(
            command: .init,
            repository: Repository(url: url),
            credentials: RepositoryCredentials(username: url.lastPathComponent, password: UUID().uuidString)
        )
    }

    public func backup(from source: URL, to destination: URL) async throws {
        try await handleResticCommand(
            command: .backup,
            repository: Repository(url: destination),
            credentials: RepositoryCredentials(username: destination.lastPathComponent, password: UUID().uuidString)
        )
    }

    public func listSnapshots() async throws -> [String] {
        let result = try await handleResticCommand(
            command: .list,
            repository: Repository(url: URL(string: "default")!),
            credentials: RepositoryCredentials(username: "default", password: UUID().uuidString)
        )
        return result.output.snapshots.map { $0.id }
    }

    public func restore(from source: URL, to destination: URL) async throws {
        try await handleResticCommand(
            command: .restore,
            repository: Repository(url: source),
            credentials: RepositoryCredentials(username: source.lastPathComponent, password: UUID().uuidString)
        )
    }

    // MARK: - Private Functions

    private func handleResticCommand(
        command: ResticCommand,
        repository: Repository,
        credentials: RepositoryCredentials,
        environment: [String: String]? = nil
    ) async throws -> ResticCommandResult {
        let operationId = UUID()
        
        do {
            // Start operation
            try await startResticOperation(operationId, command: command, repository: repository)
            
            // Validate prerequisites
            try await validateResticPrerequisites(repository: repository)
            
            // Execute command
            let result = try await executeResticCommand(
                command,
                repository: repository,
                credentials: credentials,
                environment: environment
            )
            
            // Complete operation
            try await completeResticOperation(operationId, success: true)
            
            return result
            
        } catch {
            // Handle failure
            try await completeResticOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    private func startResticOperation(
        _ id: UUID,
        command: ResticCommand,
        repository: Repository
    ) async throws {
        // Record operation start
        let operation = ResticOperation(
            id: id,
            command: command,
            repository: repository,
            timestamp: Date(),
            status: .inProgress
        )
        // operationRecorder.recordOperation(operation)
        
        // Log operation start
        logger.info("Starting restic operation", metadata: [
            "operation": .string(id.uuidString),
            "command": .string(command.rawValue),
            "repository": .string(repository.id.uuidString)
        ])
    }
    
    private func validateResticPrerequisites(repository: Repository) async throws {
        // Check restic installation
        guard try await validateResticInstallation() else {
            throw ResticError.resticNotInstalled("Restic is not installed")
        }
        
        // Validate repository access
        try await validateRepositoryAccess(repository)
        
        // Validate repository health
        try await validateRepositoryHealth(repository)
    }
    
    private func validateResticInstallation() async throws -> Bool {
        // Check if restic is installed
        let result = try await xpcService.execute(
            command: "which",
            arguments: ["restic"]
        )
        
        return result.exitCode == 0
    }
    
    private func validateRepositoryAccess(_ repository: Repository) async throws {
        guard let url = repository.url else {
            throw ResticError.invalidRepository("Repository URL is missing")
        }
        
        guard try await securityService.validateAccess(to: url) else {
            throw ResticError.accessDenied("Cannot access repository")
        }
        
        guard try await securityService.validateWriteAccess(to: url) else {
            throw ResticError.accessDenied("Cannot write to repository")
        }
    }
    
    private func validateRepositoryHealth(_ repository: Repository) async throws {
        // let health = try await healthCheckService.checkHealth(of: repository)
        // guard health.status == .healthy else {
        //     throw ResticError.unhealthyRepository(
        //         "Repository is not healthy: \(health.message ?? "Unknown error")"
        //     )
        // }
    }
    
    private func executeResticCommand(
        _ command: ResticCommand,
        repository: Repository,
        credentials: RepositoryCredentials,
        environment: [String: String]? = nil
    ) async throws -> ResticCommandResult {
        // Build command environment
        let commandEnvironment = try await buildCommandEnvironment(
            repository: repository,
            credentials: credentials,
            additionalEnvironment: environment
        )
        
        // Build command arguments
        let arguments = try await buildCommandArguments(
            command: command,
            repository: repository
        )
        
        // Execute command
        let result = try await xpcService.execute(
            command: "restic",
            arguments: arguments,
            environment: commandEnvironment
        )
        
        // Parse result
        return try await parseCommandResult(result)
    }
    
    private func buildCommandEnvironment(
        repository: Repository,
        credentials: RepositoryCredentials,
        additionalEnvironment: [String: String]? = nil
    ) async throws -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        
        // Add repository environment
        environment["RESTIC_REPOSITORY"] = repository.url?.path
        environment["RESTIC_PASSWORD"] = credentials.password
        
        // Add cache directory
        let cacheDirectory = try await getCacheDirectory(for: repository)
        environment["RESTIC_CACHE_DIR"] = cacheDirectory.path
        
        // Add compression settings
        // if repository.settings.compression {
        //     environment["RESTIC_COMPRESSION"] = "max"
        // }
        
        // Add additional environment
        if let additionalEnvironment = additionalEnvironment {
            environment.merge(additionalEnvironment) { current, _ in current }
        }
        
        return environment
    }
    
    private func buildCommandArguments(
        command: ResticCommand,
        repository: Repository
    ) async throws -> [String] {
        var arguments = [command.rawValue]
        
        // Add common arguments
        arguments.append("--json")
        arguments.append("--no-cache")
        
        // Add command-specific arguments
        switch command {
        case .init:
            break
        case .backup:
            arguments.append(contentsOf: try await buildBackupArguments(for: repository))
        case .restore:
            arguments.append(contentsOf: try await buildRestoreArguments(for: repository))
        case .check:
            arguments.append(contentsOf: try await buildCheckArguments(for: repository))
        case .list:
            arguments.append(contentsOf: try await buildListArguments(for: repository))
        case .stats:
            arguments.append(contentsOf: try await buildStatsArguments(for: repository))
        }
        
        return arguments
    }
    
    private func buildBackupArguments(for repository: Repository) async throws -> [String] {
        var arguments: [String] = []
        
        // Add compression if enabled
        // if repository.settings.compression {
        //     arguments.append("--compression=max")
        // }
        
        // Add tags
        // for tag in repository.tags {
        //     arguments.append("--tag=\(tag)")
        // }
        
        // Add excludes
        // for exclude in repository.settings.excludes {
        //     arguments.append("--exclude=\(exclude)")
        // }
        
        return arguments
    }
    
    private func buildRestoreArguments(for repository: Repository) async throws -> [String] {
        var arguments: [String] = []
        
        // Add target directory
        // if let target = repository.settings.restoreTarget {
        //     arguments.append("--target=\(target.path)")
        // }
        
        // Add verification
        // if repository.settings.verifyRestore {
        //     arguments.append("--verify")
        // }
        
        return arguments
    }
    
    private func buildCheckArguments(for repository: Repository) async throws -> [String] {
        var arguments: [String] = []
        
        // Add check options
        // if repository.settings.checkData {
        //     arguments.append("--read-data")
        // }
        
        // if repository.settings.checkUnused {
        //     arguments.append("--check-unused")
        // }
        
        return arguments
    }
    
    private func buildListArguments(for repository: Repository) async throws -> [String] {
        var arguments: [String] = []
        
        // Add list options
        // if repository.settings.listLong {
        //     arguments.append("--long")
        // }
        
        // if let host = repository.settings.listHost {
        //     arguments.append("--host=\(host)")
        // }
        
        return arguments
    }
    
    private func buildStatsArguments(for repository: Repository) async throws -> [String] {
        var arguments: [String] = []
        
        // Add stats options
        // if repository.settings.statsDetailed {
        //     arguments.append("--detailed")
        // }
        
        // if repository.settings.statsMode == .raw {
        //     arguments.append("--raw")
        // }
        
        return arguments
    }
    
    private func getCacheDirectory(for repository: Repository) async throws -> URL {
        let cacheDirectory = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let repositoryCache = cacheDirectory
            .appendingPathComponent("restic")
            .appendingPathComponent(repository.id.uuidString)
        
        try FileManager.default.createDirectory(
            at: repositoryCache,
            withIntermediateDirectories: true
        )
        
        return repositoryCache
    }
    
    private func parseCommandResult(_ result: ProcessResult) async throws -> ResticCommandResult {
        guard result.exitCode == 0 else {
            throw ResticError.commandFailed(result.error)
        }
        
        // Parse JSON output
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let output = try decoder.decode(ResticOutput.self, from: result.output.data(using: .utf8) ?? Data())
            return ResticCommandResult(
                output: output,
                error: nil
            )
        } catch {
            throw ResticError.outputParsingFailed(error)
        }
    }
    
    private func completeResticOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async throws {
        // Update operation status
        let status: ResticOperationStatus = success ? .completed : .failed
        // operationRecorder.updateOperation(id, status: status, error: error)
        
        // Log completion
        logger.info("Completed restic operation", metadata: [
            "operation": .string(id.uuidString),
            "status": .string(status.rawValue),
            "error": error.map { .string($0.localizedDescription) } ?? .string("none")
        ])
        
        // Update metrics
        if success {
            // metrics.recordSuccess()
        } else {
            // metrics.recordFailure()
        }
    }

    // MARK: - HealthCheckable Implementation

    public func performHealthCheck() async -> Bool {
        await measure("Restic Command Service Health Check") {
            do {
                // Check XPC service
                let xpcHealthy = await xpcService.ping()
                guard xpcHealthy else {
                    return false
                }

                // Check active operations
                let operationsHealthy = isHealthy

                return xpcHealthy && operationsHealthy
            } catch {
                logger.error(
                    "Health check failed: \(error.localizedDescription)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return false
            }
        }
    }
}

// MARK: - ResticCommand

enum ResticCommand: String {
    case init = "init"
    case backup = "backup"
    case restore = "restore"
    case check = "check"
    case list = "list"
    case stats = "stats"
}

// MARK: - Repository

struct Repository {
    let id = UUID()
    let url: URL?
    let tags: [String] = []
    let settings: RepositorySettings = RepositorySettings()
}

// MARK: - RepositorySettings

struct RepositorySettings {
    let compression = false
    let excludes: [String] = []
    let restoreTarget: URL?
    let verifyRestore = false
    let checkData = false
    let checkUnused = false
    let listLong = false
    let listHost: String?
    let statsDetailed = false
    let statsMode: StatsMode = .raw
}

// MARK: - StatsMode

enum StatsMode: String {
    case raw
    case humanReadable
}

// MARK: - RepositoryCredentials

struct RepositoryCredentials {
    let username: String
    let password: String
}

// MARK: - ResticOperation

struct ResticOperation {
    let id: UUID
    let command: ResticCommand
    let repository: Repository
    let timestamp: Date
    let status: ResticOperationStatus
}

// MARK: - ResticOperationStatus

enum ResticOperationStatus: String {
    case inProgress
    case completed
    case failed
}

// MARK: - ResticCommandResult

struct ResticCommandResult {
    let output: ResticOutput
    let error: Error?
}

// MARK: - ResticOutput

struct ResticOutput: Codable {
    let snapshots: [Snapshot]
}

// MARK: - Snapshot

struct Snapshot: Codable {
    let id: String
}

// MARK: - ResticError

enum ResticError: Error {
    case resticNotInstalled(String)
    case invalidRepository(String)
    case accessDenied(String)
    case unhealthyRepository(String)
    case commandFailed(Error)
    case outputParsingFailed(Error)
}
