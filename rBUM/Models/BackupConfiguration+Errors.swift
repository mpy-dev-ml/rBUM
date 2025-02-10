import Foundation

public extension BackupConfiguration {
    /// Errors that can occur when working with backup configurations
    enum ConfigurationError: LocalizedError {
        /// Invalid configuration name
        case invalidName(String)
        /// No backup sources specified
        case noSourcesSpecified(String)
        /// Failed to access source path
        case sourceAccessFailed(String)
        /// Invalid source path specified
        case invalidSource(String)
        /// Invalid exclusion pattern
        case invalidExclusionPattern(String)
        /// Invalid pattern group
        case invalidPatternGroup(String)

        public var errorDescription: String? {
            switch self {
            case let .invalidName(message),
                 let .noSourcesSpecified(message),
                 let .sourceAccessFailed(message),
                 let .invalidSource(message),
                 let .invalidExclusionPattern(message),
                 let .invalidPatternGroup(message):
                message
            }
        }
    }
}
