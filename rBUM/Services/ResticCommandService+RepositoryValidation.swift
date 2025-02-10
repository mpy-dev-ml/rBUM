import Foundation

extension ResticCommandService {
    /// Validates repository settings and configuration
    func validateRepositoryConfiguration(_ repository: Repository) throws {
        try validateBasicRepositoryRequirements(repository)
        try validateRepositorySettings(repository.settings)
        try validateRepositoryOptions(repository.options)
        try validateRepositoryCredentials(repository.credentials)
    }

    private func validateBasicRepositoryRequirements(_ repository: Repository) throws {
        // Basic path validation
        try validateRepositoryPath(repository.path)

        // Permissions check
        try validateRepositoryPermissions(repository.path)
    }

    private func validateRepositoryPath(_ path: String) throws {
        guard !path.isEmpty else {
            throw ValidationError.invalidPath("Repository path cannot be empty")
        }

        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError.invalidPath("Repository path does not exist: \(path)")
        }
    }

    private func validateRepositoryPermissions(_ path: String) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw ValidationError.invalidPath("Path does not exist: \(path)")
        }

        guard isDirectory.boolValue else {
            throw ValidationError.invalidPath("Path is not a directory: \(path)")
        }

        guard fileManager.isWritableFile(atPath: path) else {
            throw ValidationError.insufficientPermissions("No write permission: \(path)")
        }

        guard fileManager.isReadableFile(atPath: path) else {
            throw ValidationError.insufficientPermissions("No read permission: \(path)")
        }
    }

    private func validateRepositorySettings(_ settings: RepositorySettings) throws {
        try validateCompressionSettings(settings.compression)
        try validateChunkingSettings(settings.chunking)
        try validateRetentionSettings(settings.retention)
    }

    private func validateCompressionSettings(_ compression: CompressionSettings) throws {
        guard (0 ... 9).contains(compression.level) else {
            throw ValidationError.invalidCompression("Level must be between 0 and 9")
        }
    }

    private func validateChunkingSettings(_ chunking: ChunkingSettings) throws {
        guard chunking.minSize > 0 else {
            throw ValidationError.invalidChunking("Minimum size must be positive")
        }

        guard chunking.maxSize >= chunking.minSize else {
            throw ValidationError.invalidChunking("Maximum size must be >= minimum size")
        }
    }

    private func validateRetentionSettings(_ retention: RetentionSettings) throws {
        guard retention.keepLast >= 0 else {
            throw ValidationError.invalidRetention("Keep last must be non-negative")
        }

        guard retention.keepDaily >= 0 else {
            throw ValidationError.invalidRetention("Keep daily must be non-negative")
        }
    }
}
