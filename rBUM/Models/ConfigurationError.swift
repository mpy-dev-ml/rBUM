import Foundation

/// Errors that can occur when working with backup configurations
public enum ConfigurationError: LocalizedError {
    case invalidName(String)
    case noSourcesSpecified(String)
    case sourceAccessFailed(String)
    case invalidSource(String)
    case invalidExclusionPattern(String)
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
