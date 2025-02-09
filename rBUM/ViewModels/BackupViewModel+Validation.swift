import Core
import Foundation

extension BackupViewModel {
    // MARK: - Validation

    /// Validate source configuration
    func validateSource() async throws {
        guard let source = configuration.sources.first else {
            throw BackupError.missingSource("No source selected")
        }

        // Validate source URL
        guard let url = source.url else {
            throw BackupError.invalidSource("Source URL is missing")
        }

        // Validate source access
        try await securityService.validateAccess(to: url)

        // Validate source bookmark
        try await bookmarkService.validateBookmark(source.bookmark)
    }

    /// Validate repository configuration
    func validateRepository() async throws {
        guard let repository = repository else {
            throw BackupError.missingRepository("No repository selected")
        }

        // Validate repository URL
        guard let url = repository.url else {
            throw BackupError.invalidRepository("Repository URL is missing")
        }

        // Validate repository access
        try await securityService.validateAccess(to: url)
    }

    /// Validate backup credentials
    func validateCredentials() async throws {
        guard let repository = repository else { return }

        // Check if credentials exist
        guard try await credentialsService.loadCredentials(for: repository) != nil else {
            throw BackupError.missingCredentials("Repository credentials not found")
        }
    }

    /// Validate backup settings
    func validateSettings() throws {
        let settings = configuration.settings

        // Validate compression level
        guard settings.compression >= 0 && settings.compression <= 9 else {
            throw BackupError.invalidSettings("Compression level must be between 0 and 9")
        }

        // Validate encryption
        if settings.encryption {
            guard settings.password?.isEmpty == false else {
                throw BackupError.invalidSettings("Password required for encryption")
            }
        }
    }

    /// Validate the current backup configuration
    func validateConfiguration() async throws {
        // Validate basic configuration
        if includeHidden {
            // Check if we have permissions to access hidden files
            try await securityService.validateHiddenFileAccess()
        }
        
        if verifyAfterBackup {
            // Ensure we have enough disk space for verification
            try await validateAvailableSpace()
        }
        
        // Update configuration issue if any
        await MainActor.run {
            configurationIssue = nil
        }
    }
    
    /// Validate available disk space for backup operation
    private func validateAvailableSpace() async throws {
        guard let repository = repository else {
            throw BackupError.missingRepository("Repository not configured")
        }
        
        let requiredSpace = try await calculateRequiredSpace()
        let availableSpace = try await fileManager.availableSpace(at: repository.url)
        
        if availableSpace < requiredSpace {
            throw BackupError.insufficientSpace(
                "Insufficient space available. Required: \(formatBytes(requiredSpace)), " +
                "Available: \(formatBytes(availableSpace))"
            )
        }
    }
    
    /// Format bytes into human-readable string
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
