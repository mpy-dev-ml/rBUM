import Core
import Foundation

extension ResticCommandService {
    // MARK: - Command Execution

    func handleResticCommand(
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
            try await validateCommandPrerequisites(
                command: command,
                repository: repository,
                credentials: credentials
            )

            // Build command
            let arguments = try await buildCommandArguments(for: command, repository: repository)
            let commandEnvironment = try await buildCommandEnvironment(
                for: repository,
                credentials: credentials,
                additional: environment
            )

            // Execute command
            let result = try await xpcService.execute(
                command: "restic",
                arguments: arguments,
                environment: commandEnvironment
            )

            // Complete operation
            await completeResticOperation(operationId, success: true)

            return ResticCommandResult(
                output: result.output,
                exitCode: result.exitCode,
                error: result.error
            )

        } catch {
            // Handle failure
            await completeResticOperation(operationId, success: false, error: error)
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
            startTime: Date()
        )

        // Track operation
        trackOperation(id)

        // Log operation start
        logger.info("Starting Restic operation", metadata: [
            "operation": .string(id.uuidString),
            "command": .string(command.rawValue),
            "repository": .string(repository.url.path),
        ])
    }

    private func completeResticOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async {
        // Untrack operation
        untrackOperation(id)

        // Log completion
        logger.info("Completed Restic operation", metadata: [
            "operation": .string(id.uuidString),
            "success": .bool(success),
            "error": error.map { .string($0.localizedDescription) } ?? .string("none"),
        ])

        // Update metrics
        if success {
            metrics.recordSuccess()
        } else {
            metrics.recordFailure()
        }
    }

    private func validateCommandPrerequisites(
        command: ResticCommand,
        repository: Repository,
        credentials: RepositoryCredentials
    ) async throws {
        // Validate repository
        try await validateRepository(repository)

        // Validate credentials
        try await validateCredentials(credentials, for: repository)

        // Validate command-specific prerequisites
        switch command {
        case .init:
            try await validateInitPrerequisites(for: repository)
        case .backup:
            try await validateBackupPrerequisites(for: repository)
        case .restore:
            try await validateRestorePrerequisites(for: repository)
        case .list:
            try await validateListPrerequisites(for: repository)
        }
    }

    private func validateRepository(_ repository: Repository) async throws {
        // Check if repository exists
        guard fileManager.fileExists(atPath: repository.url.path) else {
            throw ResticCommandError.repositoryNotFound
        }

        // Check if repository is accessible
        guard try await securityService.validateAccess(to: repository.url) else {
            throw ResticCommandError.insufficientPermissions
        }
    }

    private func validateCredentials(
        _ credentials: RepositoryCredentials,
        for repository: Repository
    ) async throws {
        // Check if credentials exist
        guard !credentials.password.isEmpty else {
            throw ResticCommandError.invalidCredentials("Password cannot be empty")
        }

        // Check if credentials are valid
        guard try await keychainService.validateCredentials(credentials, for: repository.url) else {
            throw ResticCommandError.invalidCredentials("Invalid credentials")
        }
    }

    private func validateInitPrerequisites(for repository: Repository) async throws {
        // Check if repository already exists
        if try await isRepositoryInitialized(repository) {
            throw ResticCommandError.repositoryExists
        }
    }

    private func validateBackupPrerequisites(for repository: Repository) async throws {
        // Check if repository is initialized
        guard try await isRepositoryInitialized(repository) else {
            throw ResticCommandError.repositoryNotFound
        }
    }

    private func validateRestorePrerequisites(for repository: Repository) async throws {
        // Check if repository is initialized
        guard try await isRepositoryInitialized(repository) else {
            throw ResticCommandError.repositoryNotFound
        }
    }

    private func validateListPrerequisites(for repository: Repository) async throws {
        // Check if repository is initialized
        guard try await isRepositoryInitialized(repository) else {
            throw ResticCommandError.repositoryNotFound
        }
    }

    private func isRepositoryInitialized(_ repository: Repository) async throws -> Bool {
        // Check if config file exists
        let configPath = repository.url.appendingPathComponent("config")
        return fileManager.fileExists(atPath: configPath.path)
    }
}
