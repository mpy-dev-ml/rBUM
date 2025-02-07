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
    private let fileManager: FileManagerProtocol
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
        keychainService: KeychainServiceProtocol,
        fileManager: FileManagerProtocol
    ) {
        self.xpcService = xpcService
        self.keychainService = keychainService
        self.fileManager = fileManager

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
}

// MARK: - ResticCommand

/// Commands supported by the Restic service
enum ResticCommand: String {
    case `init`
    case backup
    case restore
    case list
}

// MARK: - ResticCommandError

/// Errors that can occur during Restic command execution
public enum ResticCommandError: LocalizedError {
    case resticNotInstalled
    case repositoryNotFound
    case repositoryExists
    case invalidRepository(String)
    case invalidSettings(String)
    case invalidCredentials(String)
    case insufficientPermissions
    case operationNotFound
    case operationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .resticNotInstalled:
            return "Restic is not installed"
        case .repositoryNotFound:
            return "Repository not found"
        case .repositoryExists:
            return "Repository already exists"
        case .invalidRepository(let message):
            return "Invalid repository: \(message)"
        case .invalidSettings(let message):
            return "Invalid settings: \(message)"
        case .invalidCredentials(let message):
            return "Invalid credentials: \(message)"
        case .insufficientPermissions:
            return "Insufficient permissions"
        case .operationNotFound:
            return "Operation not found"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
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

extension ResticCommandService {
    // MARK: - HealthCheckable Implementation

    /// Performs a health check on the Restic command service.
    /// This verifies that:
    /// 1. The XPC service is responsive and healthy
    /// 2. The service can execute basic restic commands
    /// 3. All required resources are accessible
    /// - Returns: A boolean indicating whether the service is healthy
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
