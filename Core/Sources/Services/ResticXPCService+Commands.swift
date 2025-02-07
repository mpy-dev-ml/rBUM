import Foundation
import os.log

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
        let command = ResticCommand(
            command: "init",
            arguments: [],
            environment: [:],
            workingDirectory: url.path
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

        let command = ResticCommand(
            command: "backup",
            arguments: [source.path],
            environment: [:],
            workingDirectory: destination.path
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
        let command = ResticCommand(
            command: "snapshots",
            arguments: ["--json"],
            environment: [:],
            workingDirectory: "/"
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

        let command = ResticCommand(
            command: "restore",
            arguments: ["latest", "--target", destination.path],
            environment: [:],
            workingDirectory: source.path
        )
        let result = try await executeResticCommand(command)

        if !result.succeeded {
            throw ProcessError.executionFailed("Restore command failed with exit code: \(result.exitCode)")
        }
    }
}

private extension ResticXPCService {
    private func executeResticCommand(_ command: ResticCommand) async throws -> ProcessResult {
        try await validateCommandPrerequisites(command)
        let preparedCommand = try await prepareCommand(command)
        return try await performCommand(preparedCommand)
    }

    private func validateCommandPrerequisites(_ command: ResticCommand) async throws {
        // Check connection state
        guard connectionState == .connected else {
            throw ResticXPCError.serviceUnavailable
        }

        // Validate command parameters
        try validateCommandParameters(command)

        // Check resource availability
        guard try await checkResourceAvailability(for: command) else {
            throw ResticXPCError.resourceUnavailable
        }
    }

    private func validateCommandParameters(_ command: ResticCommand) throws {
        // Validate required parameters
        guard !command.arguments.isEmpty else {
            throw ResticXPCError.invalidArguments("Command arguments cannot be empty")
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

    private func checkResourceAvailability(for command: ResticCommand) async throws -> Bool {
        // Check system resources
        let resources = try await systemMonitor.checkResources()
        guard resources.memoryAvailable > minimumMemoryRequired else {
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

    private func checkDiskSpace(for command: ResticCommand) async throws -> Bool {
        // Get repository path
        guard let repoPath = command.environment["RESTIC_REPOSITORY"] else {
            return false
        }

        // Check available space
        let url = URL(fileURLWithPath: repoPath)
        let availableSpace = try await fileManager.availableSpace(at: url)
        return availableSpace > minimumDiskSpaceRequired
    }

    private func prepareCommand(_ command: ResticCommand) async throws -> PreparedCommand {
        // Build command arguments
        var arguments = command.arguments
        arguments.insert(contentsOf: ["--json", "--quiet"], at: 0)

        // Add default environment variables
        var environment = command.environment
        environment["RESTIC_PROGRESS_FPS"] = "1"
        environment["RESTIC_CACHE_DIR"] = cacheDirectory.path

        return PreparedCommand(
            arguments: arguments,
            environment: environment,
            workingDirectory: command.workingDirectory
        )
    }

    private func performCommand(_ command: PreparedCommand) async throws -> ProcessResult {
        let operationId = UUID()

        // Start progress tracking
        progressTracker.startTracking(operationId)

        do {
            // Execute command
            let process = try await processExecutor.execute(
                command: "restic",
                arguments: command.arguments,
                environment: command.environment,
                workingDirectory: command.workingDirectory
            )

            // Monitor progress
            for try await progress in process.progress {
                progressTracker.updateProgress(
                    operationId: operationId,
                    progress: progress
                )
            }

            // Command completed successfully
            progressTracker.stopTracking(operationId)
            return process.result

        } catch {
            progressTracker.stopTracking(operationId)
            throw ResticXPCError.commandFailed(error)
        }
    }
}
