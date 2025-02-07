import Core
import Foundation

extension ResticCommandService {
    // MARK: - Validation
    
    /// Validates command prerequisites.
    ///
    /// - Parameters:
    ///   - command: The command to validate
    ///   - repository: The target repository
    ///   - credentials: The repository credentials
    /// - Throws: ResticCommandError if validation fails
    func validateCommandPrerequisites(
        command: ResticCommand,
        repository: Repository,
        credentials: RepositoryCredentials
    ) async throws {
        // Validate Restic installation
        guard try await validateResticInstallation() else {
            throw ResticCommandError.resticNotInstalled
        }
        
        // Validate repository
        try await validateRepository(repository)
        
        // Validate credentials
        try await validateCredentials(credentials)
        
        // Validate command-specific requirements
        try await validateCommandRequirements(command, for: repository)
    }
    
    /// Validates Restic installation.
    ///
    /// - Returns: True if Restic is installed
    /// - Throws: ResticCommandError if validation fails
    private func validateResticInstallation() async throws -> Bool {
        // Check if restic is installed
        let result = try await xpcService.execute(
            command: "which",
            arguments: ["restic"]
        )
        
        return result.exitCode == 0
    }
    
    /// Validates a repository.
    ///
    /// - Parameter repository: The repository to validate
    /// - Throws: ResticCommandError if validation fails
    private func validateRepository(_ repository: Repository) async throws {
        // Check repository path
        guard !repository.path.isEmpty else {
            throw ResticCommandError.invalidRepository("Repository path cannot be empty")
        }
        
        // Check repository permissions
        guard try await securityService.hasAccess(to: URL(fileURLWithPath: repository.path)) else {
            throw ResticCommandError.insufficientPermissions
        }
        
        // Check repository settings
        try validateRepositorySettings(repository.settings)
    }
    
    /// Validates repository settings.
    ///
    /// - Parameter settings: The settings to validate
    /// - Throws: ResticCommandError if validation fails
    private func validateRepositorySettings(_ settings: RepositorySettings) throws {
        // Check backup sources
        if let sources = settings.backupSources {
            guard !sources.isEmpty else {
                throw ResticCommandError.invalidSettings("Backup sources cannot be empty")
            }
        }
        
        // Check exclude patterns
        if let excludes = settings.excludePatterns {
            for pattern in excludes {
                guard !pattern.isEmpty else {
                    throw ResticCommandError.invalidSettings("Exclude pattern cannot be empty")
                }
            }
        }
        
        // Check include patterns
        if let includes = settings.includePatterns {
            for pattern in includes {
                guard !pattern.isEmpty else {
                    throw ResticCommandError.invalidSettings("Include pattern cannot be empty")
                }
            }
        }
        
        // Check tags
        if let tags = settings.tags {
            for tag in tags {
                guard !tag.isEmpty else {
                    throw ResticCommandError.invalidSettings("Tag cannot be empty")
                }
            }
        }
    }
    
    /// Validates repository credentials.
    ///
    /// - Parameter credentials: The credentials to validate
    /// - Throws: ResticCommandError if validation fails
    private func validateCredentials(_ credentials: RepositoryCredentials) async throws {
        // Check password
        guard !credentials.password.isEmpty else {
            throw ResticCommandError.invalidCredentials("Password cannot be empty")
        }
        
        // Check username if provided
        if !credentials.username.isEmpty {
            guard credentials.username.count >= 3 else {
                throw ResticCommandError.invalidCredentials("Username must be at least 3 characters")
            }
        }
    }
    
    /// Validates command-specific requirements.
    ///
    /// - Parameters:
    ///   - command: The command to validate
    ///   - repository: The target repository
    /// - Throws: ResticCommandError if validation fails
    private func validateCommandRequirements(
        _ command: ResticCommand,
        for repository: Repository
    ) async throws {
        switch command {
        case .init:
            // Repository should not exist
            guard !try await fileManager.fileExists(at: URL(fileURLWithPath: repository.path)) else {
                throw ResticCommandError.repositoryExists
            }
            
        case .backup:
            // Check backup sources
            guard let sources = repository.settings.backupSources, !sources.isEmpty else {
                throw ResticCommandError.invalidSettings("Backup sources required")
            }
            
            // Check source permissions
            for source in sources {
                guard try await securityService.hasAccess(to: URL(fileURLWithPath: source)) else {
                    throw ResticCommandError.insufficientPermissions
                }
            }
            
        case .restore:
            // Check restore target
            guard let target = repository.settings.restoreTarget else {
                throw ResticCommandError.invalidSettings("Restore target required")
            }
            
            // Check target permissions
            guard try await securityService.hasAccess(to: URL(fileURLWithPath: target)) else {
                throw ResticCommandError.insufficientPermissions
            }
            
        case .list:
            // Repository should exist
            guard try await fileManager.fileExists(at: URL(fileURLWithPath: repository.path)) else {
                throw ResticCommandError.repositoryNotFound
            }
        }
    }
}
