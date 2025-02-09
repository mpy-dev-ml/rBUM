import Foundation

/// Service for persisting and retrieving maintenance configurations
public final class MaintenanceConfigurationStore {
    private let fileManager: FileManager
    private let logger: LoggerProtocol
    private let configDirectory: URL
    
    /// Configuration file types for persistence
    private enum ConfigFile: String {
        /// File name for task configurations
        case taskConfigurations = "task_configurations.json"
        /// File name for maintenance schedules
        case schedules = "maintenance_schedules.json"
        /// File name for maintenance history
        case history = "maintenance_history.json"
    }
    
    /// Initializes a new instance of the maintenance configuration store
    ///
    /// - Parameters:
    ///   - fileManager: The file manager to use for persistence (defaults to `.default`)
    ///   - logger: The logger to use for logging events
    ///   - applicationSupport: The application support directory to use for persistence (optional)
    public init(
        fileManager: FileManager = .default,
        logger: LoggerProtocol,
        applicationSupport: URL? = nil
    ) throws {
        self.fileManager = fileManager
        self.logger = logger
        
        // Get application support directory
        let appSupport = applicationSupport ?? try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("com.rbum", isDirectory: true)
            .appendingPathComponent("maintenance", isDirectory: true)
        
        self.configDirectory = appSupport
        
        // Create directory if needed
        if !fileManager.fileExists(atPath: appSupport.path) {
            try fileManager.createDirectory(
                at: appSupport,
                withIntermediateDirectories: true
            )
        }
    }
    
    // MARK: - Task Configurations
    
    /// Saves task configurations to disk
    ///
    /// - Parameters:
    ///   - configurations: The task configurations to save
    public func saveTaskConfigurations(
        _ configurations: [MaintenanceTask: TaskConfiguration]
    ) throws {
        let url = configDirectory.appendingPathComponent(ConfigFile.taskConfigurations.rawValue)
        let data = try JSONEncoder().encode(configurations)
        try data.write(to: url, options: .atomic)
        logger.info("Saved task configurations")
    }
    
    /// Loads task configurations from disk
    ///
    /// - Returns: The loaded task configurations, or defaults if none are found
    public func loadTaskConfigurations() throws -> [MaintenanceTask: TaskConfiguration] {
        let url = configDirectory.appendingPathComponent(ConfigFile.taskConfigurations.rawValue)
        
        guard fileManager.fileExists(atPath: url.path) else {
            logger.info("No saved task configurations found, using defaults")
            return TaskConfiguration.defaults
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([MaintenanceTask: TaskConfiguration].self, from: data)
    }
    
    // MARK: - Maintenance Schedules
    
    /// Saves maintenance schedules to disk
    ///
    /// - Parameters:
    ///   - schedules: The maintenance schedules to save
    public func saveSchedules(_ schedules: [String: MaintenanceSchedule]) throws {
        let url = configDirectory.appendingPathComponent(ConfigFile.schedules.rawValue)
        let data = try JSONEncoder().encode(schedules)
        try data.write(to: url, options: .atomic)
        logger.info("Saved maintenance schedules")
    }
    
    /// Loads maintenance schedules from disk
    ///
    /// - Returns: The loaded maintenance schedules, or an empty dictionary if none are found
    public func loadSchedules() throws -> [String: MaintenanceSchedule] {
        let url = configDirectory.appendingPathComponent(ConfigFile.schedules.rawValue)
        
        guard fileManager.fileExists(atPath: url.path) else {
            logger.info("No saved maintenance schedules found")
            return [:]
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: MaintenanceSchedule].self, from: data)
    }
    
    // MARK: - Maintenance History
    
    /// Saves maintenance history to disk
    ///
    /// - Parameters:
    ///   - history: The maintenance history to save
    public func saveHistory(_ history: [String: [MaintenanceResult]]) throws {
        let url = configDirectory.appendingPathComponent(ConfigFile.history.rawValue)
        let data = try JSONEncoder().encode(history)
        try data.write(to: url, options: .atomic)
        logger.info("Saved maintenance history")
    }
    
    /// Loads maintenance history from disk
    ///
    /// - Returns: The loaded maintenance history, or an empty dictionary if none is found
    public func loadHistory() throws -> [String: [MaintenanceResult]] {
        let url = configDirectory.appendingPathComponent(ConfigFile.history.rawValue)
        
        guard fileManager.fileExists(atPath: url.path) else {
            logger.info("No saved maintenance history found")
            return [:]
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: [MaintenanceResult]].self, from: data)
    }
}
