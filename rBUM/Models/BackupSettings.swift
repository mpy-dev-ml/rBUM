import Foundation

/// Settings for backup operations
public struct BackupSettings: Codable, Equatable {
    /// Maximum number of concurrent backup operations
    public let maxConcurrentBackups: Int

    /// Whether to exclude hidden files from backups
    public let excludeHiddenFiles: Bool

    /// Whether to exclude system files from backups
    public let excludeSystemFiles: Bool

    /// Whether to exclude temporary files from backups
    public let excludeTemporaryFiles: Bool

    /// Whether to exclude cache directories from backups
    public let excludeCaches: Bool

    /// Key for storing settings in UserDefaults
    static let defaultsKey = "dev.mpy.rBUM.backupSettings"

    /// Create settings with specified values
    public init(
        maxConcurrentBackups: Int = 2,
        excludeHiddenFiles: Bool = false,
        excludeSystemFiles: Bool = false,
        excludeTemporaryFiles: Bool = true,
        excludeCaches: Bool = true
    ) {
        self.maxConcurrentBackups = maxConcurrentBackups
        self.excludeHiddenFiles = excludeHiddenFiles
        self.excludeSystemFiles = excludeSystemFiles
        self.excludeTemporaryFiles = excludeTemporaryFiles
        self.excludeCaches = excludeCaches
    }

    /// Load settings from UserDefaults
    public static func load(from defaults: UserDefaults) -> BackupSettings? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(BackupSettings.self, from: data)
    }

    /// Save settings to UserDefaults
    public func save(to defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(self)
        defaults.set(data, forKey: Self.defaultsKey)
    }

    /// Check if a path should be excluded based on current settings
    public func shouldExclude(_ path: String) -> Bool {
        // Empty paths are never excluded
        guard !path.isEmpty else { return false }

        // Check path against exclusion settings
        if excludeHiddenFiles, path.hasPrefix(".") { return true }
        if excludeSystemFiles, path.contains("/System/") { return true }
        if excludeTemporaryFiles, path.contains("/tmp/") { return true }
        if excludeCaches, path.contains("/Caches/") { return true }

        return false
    }
}
