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
