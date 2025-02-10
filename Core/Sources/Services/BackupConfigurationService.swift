import Foundation

/// Service for managing backup configurations
public actor BackupConfigurationService {
    // MARK: - Properties

    private let logger: LoggerProtocol
    private let fileManager: FileManagerProtocol
    private let storage: BackupConfigurationStorageProtocol
    private var activeConfigurations: [BackupConfiguration] = []

    // MARK: - Initialization

    /// Initialise the backup configuration service
    /// - Parameters:
    ///   - logger: Logger for service operations
    ///   - fileManager: FileManager for file operations
    ///   - storage: Storage for backup configurations
    public init(
        logger: LoggerProtocol,
        fileManager: FileManagerProtocol,
        storage: BackupConfigurationStorageProtocol
    ) {
        self.logger = logger
        self.fileManager = fileManager
        self.storage = storage
    }

    /// Load saved configurations
    public func loadConfigurations() async throws {
        logger.debug("Loading saved configurations", privacy: .public)
        activeConfigurations = try await storage.loadConfigurations()
        logger.debug("Loaded \(activeConfigurations.count) configurations", privacy: .public)
    }

    // MARK: - Configuration Management

    /// Create a new backup configuration
    /// - Parameters:
    ///   - name: Name of the backup configuration
    ///   - description: Optional description of what this backup does
    ///   - enabled: Whether this backup configuration is enabled
    ///   - schedule: Schedule for running the backup
    ///   - sources: Source locations to backup
    ///   - includeHidden: Whether to include hidden files in backup
    ///   - verifyAfterBackup: Whether to verify after backup completion
    ///   - repository: Repository to use for backup
    /// - Returns: The created backup configuration
    public func createConfiguration(
        name: String,
        description: String? = nil,
        enabled: Bool = true,
        schedule: BackupSchedule? = nil,
        sources: [URL],
        includeHidden: Bool = false,
        verifyAfterBackup: Bool = true,
        repository: Repository? = nil
    ) async throws -> BackupConfiguration {
        logger.debug("Creating backup configuration: \(name)", privacy: .public)

        // Create the configuration
        let configuration = try BackupConfiguration(
            name: name,
            description: description,
            enabled: enabled,
            schedule: schedule,
            sources: sources,
            includeHidden: includeHidden,
            verifyAfterBackup: verifyAfterBackup,
            repository: repository
        )

        // Store the configuration
        activeConfigurations.append(configuration)

        // Save to persistent storage
        try await storage.saveConfigurations(activeConfigurations)

        logger.debug("Created backup configuration with ID: \(configuration.id)", privacy: .public)
        return configuration
    }

    /// Start accessing sources for a backup configuration
    /// - Parameter configurationId: ID of the configuration to start accessing
    /// - Throws: Error if configuration not found or access cannot be started
    public func startAccessing(configurationId: UUID) async throws {
        guard let index = activeConfigurations.firstIndex(where: { $0.id == configurationId }) else {
            logger.error("Configuration not found: \(configurationId)", privacy: .public)
            throw BackupConfigurationError.configurationNotFound(configurationId)
        }

        logger.debug("Starting access for configuration: \(configurationId)", privacy: .public)
        try activeConfigurations[index].startAccessing()
    }

    /// Stop accessing sources for a backup configuration
    /// - Parameter configurationId: ID of the configuration to stop accessing
    public func stopAccessing(configurationId: UUID) async {
        guard let index = activeConfigurations.firstIndex(where: { $0.id == configurationId }) else {
            logger.warning("Configuration not found for stopping access: \(configurationId)", privacy: .public)
            return
        }

        logger.debug("Stopping access for configuration: \(configurationId)", privacy: .public)
        activeConfigurations[index].stopAccessing()
    }

    /// Get all backup configurations
    /// - Returns: Array of backup configurations
    public func getConfigurations() async -> [BackupConfiguration] {
        activeConfigurations
    }

    /// Get a specific backup configuration
    /// - Parameter id: ID of the configuration to get
    /// - Returns: The backup configuration if found
    /// - Throws: BackupConfigurationError if configuration not found
    public func getConfiguration(id: UUID) async throws -> BackupConfiguration {
        guard let configuration = activeConfigurations.first(where: { $0.id == id }) else {
            logger.error("Configuration not found: \(id)", privacy: .public)
            throw BackupConfigurationError.configurationNotFound(id)
        }
        return configuration
    }
}

/// Errors that can occur when working with backup configurations
public enum BackupConfigurationError: LocalizedError {
    case configurationNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case let .configurationNotFound(id):
            "Backup configuration not found with ID: \(id)"
        }
    }
}
