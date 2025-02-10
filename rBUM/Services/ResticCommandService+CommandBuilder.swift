import Core
import Foundation

extension ResticCommandService {
    // MARK: - Command Building

    /// Builds command arguments for a Restic command.
    ///
    /// - Parameters:
    ///   - command: The command to build arguments for
    ///   - repository: The target repository
    /// - Returns: Array of command arguments
    /// - Throws: ResticCommandError if argument building fails
    func buildCommandArguments(
        for command: ResticCommand,
        repository: Repository
    ) async throws -> [String] {
        switch command {
        case .init:
            try await buildInitArguments(for: repository)
        case .backup:
            try await buildBackupArguments(for: repository)
        case .restore:
            try await buildRestoreArguments(for: repository)
        case .list:
            try await buildListArguments(for: repository)
        }
    }

    /// Builds command environment variables.
    ///
    /// - Parameters:
    ///   - repository: The target repository
    ///   - credentials: The repository credentials
    ///   - additional: Additional environment variables
    /// - Returns: Dictionary of environment variables
    /// - Throws: ResticCommandError if environment building fails
    func buildCommandEnvironment(
        for repository: Repository,
        credentials: RepositoryCredentials,
        additional: [String: String]? = nil
    ) async throws -> [String: String] {
        var environment = [String: String]()

        // Add repository path
        environment["RESTIC_REPOSITORY"] = repository.path

        // Add credentials
        environment["RESTIC_PASSWORD"] = credentials.password
        if !credentials.username.isEmpty {
            environment["RESTIC_USERNAME"] = credentials.username
        }

        // Add additional variables
        if let additional {
            environment.merge(additional) { current, _ in current }
        }

        return environment
    }

    // MARK: - Private Command Building

    private func buildInitArguments(for repository: Repository) async throws -> [String] {
        var arguments = ["init"]

        // Add repository path
        arguments.append(repository.path)

        return arguments
    }

    private func buildBackupArguments(for repository: Repository) async throws -> [String] {
        var arguments = ["backup"]

        // Add source paths
        if let sources = repository.settings.backupSources {
            arguments.append(contentsOf: sources)
        }

        // Add exclude patterns
        if let excludes = repository.settings.excludePatterns {
            for pattern in excludes {
                arguments.append("--exclude")
                arguments.append(pattern)
            }
        }

        // Add tags
        if let tags = repository.settings.tags {
            for tag in tags {
                arguments.append("--tag")
                arguments.append(tag)
            }
        }

        return arguments
    }

    private func buildRestoreArguments(for repository: Repository) async throws -> [String] {
        var arguments = ["restore", "latest"]

        // Add target directory
        if let target = repository.settings.restoreTarget {
            arguments.append("--target")
            arguments.append(target)
        }

        // Add include patterns
        if let includes = repository.settings.includePatterns {
            for pattern in includes {
                arguments.append("--include")
                arguments.append(pattern)
            }
        }

        return arguments
    }

    private func buildListArguments(for repository: Repository) async throws -> [String] {
        var arguments = ["snapshots"]

        // Add JSON output format
        arguments.append("--json")

        // Add path filter
        if let path = repository.settings.pathFilter {
            arguments.append("--path")
            arguments.append(path)
        }

        // Add tag filter
        if let tags = repository.settings.tags {
            for tag in tags {
                arguments.append("--tag")
                arguments.append(tag)
            }
        }

        return arguments
    }
}
