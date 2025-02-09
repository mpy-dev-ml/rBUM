import Foundation

extension BackupConfiguration {
    /// Errors that can occur when working with backup configurations
    public enum ConfigurationError: LocalizedError {
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
            case .invalidName(let message),
                 .noSourcesSpecified(let message),
                 .sourceAccessFailed(let message),
                 .invalidSource(let message),
                 .invalidExclusionPattern(let message),
                 .invalidPatternGroup(let message):
                return message
            }
        }
    }
}
