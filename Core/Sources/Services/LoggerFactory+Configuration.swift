import Foundation

public extension LoggerFactory {
    // MARK: - Configuration

    /// Configuration options for loggers
    struct Configuration {
        /// The subsystem identifier for all loggers
        public static let subsystem = "dev.mpy.rBUM"

        /// Default configuration options
        public static let `default` = Configuration()

        /// Whether to include source file information in log messages
        public let includeSourceInfo: Bool

        /// Whether to include timestamps in log messages
        public let includeTimestamps: Bool

        /// Whether to include the subsystem in log messages
        public let includeSubsystem: Bool

        /// Creates a new configuration with the specified options
        ///
        /// - Parameters:
        ///   - includeSourceInfo: Whether to include source file information
        ///   - includeTimestamps: Whether to include timestamps
        ///   - includeSubsystem: Whether to include the subsystem
        public init(
            includeSourceInfo: Bool = true,
            includeTimestamps: Bool = true,
            includeSubsystem: Bool = false
        ) {
            self.includeSourceInfo = includeSourceInfo
            self.includeTimestamps = includeTimestamps
            self.includeSubsystem = includeSubsystem
        }
    }

    /// Current configuration for all loggers
    static var configuration: Configuration = .default
}
