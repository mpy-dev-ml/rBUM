import Foundation

/// Protocol for storing and retrieving backup configurations
public protocol BackupConfigurationStorageProtocol {
    /// Save backup configurations
    /// - Parameter configurations: Configurations to save
    func saveConfigurations(_ configurations: [BackupConfiguration]) async throws

    /// Load backup configurations
    /// - Returns: Array of saved configurations
    func loadConfigurations() async throws -> [BackupConfiguration]
}

/// Manages persistent storage of backup configurations
public actor BackupConfigurationStorage: BackupConfigurationStorageProtocol {
    // MARK: - Properties

    private let logger: LoggerProtocol
    private let fileManager: FileManagerProtocol
    private let storageURL: URL

    // MARK: - Initialization

    /// Initialise backup configuration storage
    /// - Parameters:
    ///   - logger: Logger for storage operations
    ///   - fileManager: FileManager for file operations
    public init(
        logger: LoggerProtocol,
        fileManager: FileManagerProtocol
    ) throws {
        self.logger = logger
        self.fileManager = fileManager

        // Get application support directory
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        // Create storage directory
        storageURL = appSupport
            .appendingPathComponent("dev.mpy.rBUM", isDirectory: true)
            .appendingPathComponent("Configurations", isDirectory: true)

        try fileManager.createDirectory(
            at: storageURL,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Storage Operations

    public func saveConfigurations(_ configurations: [BackupConfiguration]) async throws {
        logger.debug("Saving \(configurations.count) configurations", privacy: .public)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(configurations)
        let fileURL = storageURL.appendingPathComponent("configurations.json")

        try data.write(to: fileURL, options: .atomic)
        logger.debug("Saved configurations to: \(fileURL.path)", privacy: .public)
    }

    public func loadConfigurations() async throws -> [BackupConfiguration] {
        let fileURL = storageURL.appendingPathComponent("configurations.json")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.debug("No saved configurations found", privacy: .public)
            return []
        }

        logger.debug("Loading configurations from: \(fileURL.path)", privacy: .public)
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let configurations = try decoder.decode([BackupConfiguration].self, from: data)

        logger.debug("Loaded \(configurations.count) configurations", privacy: .public)
        return configurations
    }
}
