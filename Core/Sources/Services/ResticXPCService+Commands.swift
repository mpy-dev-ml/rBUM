//
//  ResticXPCService+Commands.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 8 February 2025
//
import Foundation
import os.log

// MARK: - Constants

private extension ResticXPCService {
    /// Minimum required memory in bytes (512MB)
    static let minimumMemoryRequired: UInt64 = 512 * 1024 * 1024

    /// Minimum required disk space in bytes (1GB)
    static let minimumDiskSpaceRequired: Int64 = 1024 * 1024 * 1024

    /// Cache directory name
    static let cacheDirName = "ResticCache"
}

// MARK: - Properties

extension ResticXPCService {
    /// Cache directory for Restic operations
    var cacheDirectory: URL {
        get throws {
            let fileManager = FileManager.default
            let cacheDir = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let resticCacheDir = cacheDir.appendingPathComponent(Self.cacheDirName)

            if !fileManager.fileExists(atPath: resticCacheDir.path) {
                try fileManager.createDirectory(
                    at: resticCacheDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            return resticCacheDir
        }
    }
}

// MARK: - ResticServiceProtocol Implementation

@available(macOS 13.0, *)
public extension ResticXPCService {
    /// Initializes a new Restic repository at the specified URL
    /// - Parameter url: The URL where the repository should be initialized
    /// - Throws: ProcessError if the initialization fails
    func initializeRepository(at url: URL) async throws {
        logger.info(
            "Initializing repository at \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        // Initialize repository
        let command = XPCCommandConfig(
            command: "init",
            arguments: [],
            environment: [:],
            workingDirectory: url.path,
            bookmarks: [:],
            timeout: 30,
            auditSessionId: au_session_self()
        )
        _ = try await executeResticCommand(command)
    }

    /// Creates a backup from the source directory to the destination repository
    /// - Parameters:
    ///   - source: The URL of the directory to backup
    ///   - destination: The URL of the Restic repository
    /// - Throws: ProcessError if the backup operation fails
    func backup(from source: URL, to destination: URL) async throws {
        logger.info(
            "Backing up \(source.path) to \(destination.path)",
            file: #file,
            function: #function,
            line: #line
        )

        let command = XPCCommandConfig(
            command: "backup",
            arguments: [source.path],
            environment: [:],
            workingDirectory: destination.path,
            bookmarks: [:],
            timeout: 3600,
            auditSessionId: au_session_self()
        )
        let result = try await executeResticCommand(command)

        if !result.succeeded {
            throw ProcessError.executionFailed("Backup command failed with exit code: \(result.exitCode)")
        }
    }

    /// Lists all snapshots in the repository
    /// - Returns: An array of snapshot IDs
    /// - Throws: ProcessError if the list operation fails
    func listSnapshots() async throws -> [String] {
        let command = XPCCommandConfig(
            command: "snapshots",
            arguments: ["--json"],
            environment: [:],
            workingDirectory: "/",
            bookmarks: [:],
            timeout: 30,
            auditSessionId: au_session_self()
        )
        let result = try await executeResticCommand(command)

        // Parse JSON output to extract snapshot IDs
        // This is a simplified implementation
        return result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    /// Restores data from a repository snapshot to a destination directory
    /// - Parameters:
    ///   - source: The URL of the Restic repository containing the snapshot
    ///   - destination: The URL where the data should be restored
    /// - Throws: ProcessError if the restore operation fails
    func restore(from source: URL, to destination: URL) async throws {
        logger.info(
            "Restoring from \(source.path) to \(destination.path)",
            file: #file,
            function: #function,
            line: #line
        )

        let command = XPCCommandConfig(
            command: "restore",
            arguments: ["latest", "--target", destination.path],
            environment: [:],
            workingDirectory: source.path,
            bookmarks: [:],
            timeout: 3600,
            auditSessionId: au_session_self()
        )
        let result = try await executeResticCommand(command)

        if !result.succeeded {
            throw ProcessError.executionFailed("Restore command failed with exit code: \(result.exitCode)")
        }
    }
}

private extension ResticXPCService {
    private func executeResticCommand(_ command: XPCCommandConfig) async throws -> ProcessResult {
        try await validateCommandPrerequisites(command)
        let preparedCommand = try await prepareCommand(command)
        return try await executeCommand(preparedCommand)
    }

    private func validateCommandPrerequisites(_ command: XPCCommandConfig) async throws {
        // Check connection state
        guard connectionState == .connected else {
            throw ResticXPCError.serviceUnavailable("Service is not connected")
        }

        // Validate command parameters
        try validateCommandParameters(command)

        // Check resource availability
        guard try await checkResourceAvailability(for: command) else {
            throw ResticXPCError.resourceUnavailable("Required resources are not available")
        }
    }

    private func validateCommandParameters(_ command: XPCCommandConfig) throws {
        // Validate required parameters
        guard !command.command.isEmpty else {
            throw ResticXPCError.invalidArguments("Command cannot be empty")
        }

        // Check for unsafe arguments
        let unsafeArguments = ["--no-cache", "--no-lock", "--force"]
        guard !command.arguments.contains(where: unsafeArguments.contains) else {
            throw ResticXPCError.unsafeArguments("Command contains unsafe arguments")
        }

        // Validate environment variables
        try validateEnvironmentVariables(command.environment)
    }

    private func validateEnvironmentVariables(_ environment: [String: String]) throws {
        let requiredVariables = ["RESTIC_PASSWORD", "RESTIC_REPOSITORY"]
        for variable in requiredVariables {
            guard environment[variable] != nil else {
                throw ResticXPCError.missingEnvironment("Missing required environment variable: \(variable)")
            }
        }
    }

    private func checkResourceAvailability(for command: XPCCommandConfig) async throws -> Bool {
        // Check system resources
        let resources = try await systemMonitor.checkResources()
        guard resources.memoryAvailable > Self.minimumMemoryRequired else {
            logger.error("Insufficient memory available")
            return false
        }

        // Check disk space
        guard try await checkDiskSpace(for: command) else {
            logger.error("Insufficient disk space")
            return false
        }

        return true
    }

    private func checkDiskSpace(for command: XPCCommandConfig) async throws -> Bool {
        // Get repository path
        guard let repoPath = command.environment["RESTIC_REPOSITORY"] else {
            return false
        }

        // Check available space
        let url = URL(fileURLWithPath: repoPath)
        let availableSpace = try await fileManager.availableSpace(at: url)
        return availableSpace > Self.minimumDiskSpaceRequired
    }

    private func prepareCommand(_ command: XPCCommandConfig) async throws -> PreparedCommand {
        // Build command arguments
        var arguments = command.arguments
        arguments.insert(contentsOf: ["--json", "--quiet"], at: 0)

        // Add default environment variables
        var environment = command.environment
        environment["RESTIC_PROGRESS_FPS"] = "1"
        environment["RESTIC_CACHE_DIR"] = try cacheDirectory.path

        return PreparedCommand(
            command: "restic",
            arguments: arguments,
            environment: environment,
            workingDirectory: command.workingDirectory
        )
    }

    private func executeCommand(_ command: PreparedCommand) async throws -> ProcessResult {
        let operationId = UUID()

        // Start progress tracking
        progressTracker.startOperation(operationId)

        do {
            // Execute command
            let process = try await processExecutor.execute(
                command: command.command,
                arguments: command.arguments,
                environment: command.environment,
                workingDirectory: command.workingDirectory
            )

            // Update progress
            progressTracker.updateProgress(operationId, progress: 1.0)

            return process
        } catch {
            // Handle execution error
            progressTracker.failOperation(operationId, error: error)
            throw ResticXPCError.executionFailed("Command execution failed: \(error.localizedDescription)")
        }
    }
}
