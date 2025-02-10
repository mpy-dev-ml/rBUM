import Core
import Foundation

extension BackupService {
    // MARK: - Validation

    /// Validates backup prerequisites.
    ///
    /// - Parameters:
    ///   - source: The source URL for the backup
    ///   - destination: The destination repository
    ///   - options: Backup options
    /// - Throws: BackupError if validation fails
    func validateBackupPrerequisites(
        source: URL,
        destination: Repository,
        options: BackupOptions
    ) async throws {
        // Validate source
        try await validateSource(source)

        // Validate destination
        try await validateDestination(destination)

        // Validate options
        try await validateOptions(options)
    }

    /// Validates a backup source.
    ///
    /// - Parameter source: The source URL to validate
    /// - Throws: BackupError if validation fails
    private func validateSource(_ source: URL) async throws {
        // Check if source exists
        guard try await fileManager.fileExists(at: source) else {
            throw BackupError.invalidSource("Source does not exist")
        }

        // Check source permissions
        guard try await fileManager.isReadable(at: source) else {
            throw BackupError.invalidSource("Source is not readable")
        }

        // Check source size
        if try await fileManager.isDirectory(at: source) {
            try await validateSourceDirectory(source)
        } else {
            try await validateSourceFile(source)
        }
    }

    /// Validates a source directory.
    ///
    /// - Parameter url: The directory URL to validate
    /// - Throws: BackupError if validation fails
    private func validateSourceDirectory(_ url: URL) async throws {
        // Check directory permissions
        guard try await fileManager.isReadable(at: url) else {
            throw BackupError.invalidSource("Directory is not readable")
        }

        // Check directory contents
        let contents = try await fileManager.contentsOfDirectory(at: url)

        // Check each item
        for item in contents {
            if try await fileManager.isDirectory(at: item) {
                try await validateSourceDirectory(item)
            } else {
                try await validateSourceFile(item)
            }
        }
    }

    /// Validates a source file.
    ///
    /// - Parameter url: The file URL to validate
    /// - Throws: BackupError if validation fails
    private func validateSourceFile(_ url: URL) async throws {
        // Check file permissions
        guard try await fileManager.isReadable(at: url) else {
            throw BackupError.invalidSource("File is not readable")
        }

        // Check file size
        let size = try await fileManager.size(of: url)
        guard size > 0 else {
            throw BackupError.invalidSource("File is empty")
        }
    }

    /// Validates a backup destination.
    ///
    /// - Parameter destination: The destination repository to validate
    /// - Throws: BackupError if validation fails
    private func validateDestination(_ destination: Repository) async throws {
        // Check if repository exists
        guard try await fileManager.fileExists(at: URL(fileURLWithPath: destination.path)) else {
            throw BackupError.invalidDestination("Repository does not exist")
        }

        // Check repository permissions
        guard try await fileManager.isWritable(at: URL(fileURLWithPath: destination.path)) else {
            throw BackupError.invalidDestination("Repository is not writable")
        }

        // Check repository credentials
        guard try await credentialsService.hasCredentials(for: destination) else {
            throw BackupError.invalidDestination("Repository credentials not found")
        }

        // Check repository health
        guard try await resticService.check(destination) else {
            throw BackupError.invalidDestination("Repository health check failed")
        }
    }

    /// Validates backup options.
    ///
    /// - Parameter options: The backup options to validate
    /// - Throws: BackupError if validation fails
    private func validateOptions(_ options: BackupOptions) async throws {
        // Validate compression settings
        if options.compression {
            try await validateCompressionSettings(options.compressionLevel)
        }

        // Validate encryption settings
        if options.encryption {
            try await validateEncryptionSettings(options.encryptionKey)
        }

        // Validate chunk size
        try await validateChunkSize(options.chunkSize)
    }

    /// Validates compression settings.
    ///
    /// - Parameter level: The compression level to validate
    /// - Throws: BackupError if validation fails
    private func validateCompressionSettings(_ level: Int) async throws {
        // Check compression level range
        guard (1 ... 9).contains(level) else {
            throw BackupError.invalidOptions("Compression level must be between 1 and 9")
        }

        // Check system resources
        guard try await hasRequiredResources(for: level) else {
            throw BackupError.insufficientResources("Insufficient resources for compression level")
        }
    }

    /// Validates encryption settings.
    ///
    /// - Parameter key: The encryption key to validate
    /// - Throws: BackupError if validation fails
    private func validateEncryptionSettings(_ key: String?) async throws {
        // Check if key is provided
        guard let key else {
            throw BackupError.invalidOptions("Encryption key is required")
        }

        // Validate key strength
        guard try await validateKeyStrength(key) else {
            throw BackupError.invalidOptions("Encryption key is too weak")
        }
    }

    /// Validates chunk size.
    ///
    /// - Parameter size: The chunk size to validate
    /// - Throws: BackupError if validation fails
    private func validateChunkSize(_ size: UInt64) async throws {
        // Check minimum size
        guard size >= 1024 * 1024 else { // 1MB
            throw BackupError.invalidOptions("Chunk size must be at least 1MB")
        }

        // Check maximum size
        guard size <= 1024 * 1024 * 1024 else { // 1GB
            throw BackupError.invalidOptions("Chunk size must be at most 1GB")
        }

        // Check if size is power of 2
        guard (size & (size - 1)) == 0 else {
            throw BackupError.invalidOptions("Chunk size must be a power of 2")
        }
    }

    /// Checks if system has required resources.
    ///
    /// - Parameter compressionLevel: The compression level to check resources for
    /// - Returns: True if system has required resources
    /// - Throws: BackupError if check fails
    private func hasRequiredResources(for compressionLevel: Int) async throws -> Bool {
        // Get system info
        let systemInfo = try await systemMonitor.getSystemInfo()

        // Calculate required memory
        let requiredMemory = UInt64(compressionLevel) * 1024 * 1024 * 1024 // GB

        return systemInfo.availableMemory >= requiredMemory
    }

    /// Validates encryption key strength.
    ///
    /// - Parameter key: The key to validate
    /// - Returns: True if key is strong enough
    /// - Throws: BackupError if validation fails
    private func validateKeyStrength(_ key: String) async throws -> Bool {
        // Check key length
        guard key.count >= 16 else {
            return false
        }

        // Check key complexity
        let hasUppercase = key.contains { $0.isUppercase }
        let hasLowercase = key.contains { $0.isLowercase }
        let hasNumber = key.contains { $0.isNumber }
        let hasSpecial = key.contains { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }

        return hasUppercase && hasLowercase && hasNumber && hasSpecial
    }
}
