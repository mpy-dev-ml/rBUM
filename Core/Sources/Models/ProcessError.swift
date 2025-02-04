import Foundation

/// Errors that can occur during process execution
public enum ProcessError: LocalizedError {
    case executionFailed(String)
    case invalidExecutable(String)
    case sandboxViolation(String)
    case timeout(String)
    case environmentError(String)
    
    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Process execution failed: \(message)"
        case .invalidExecutable(let path):
            return "Invalid executable at path: \(path)"
        case .sandboxViolation(let message):
            return "Sandbox violation: \(message)"
        case .timeout(let message):
            return "Process timed out: \(message)"
        case .environmentError(let message):
            return "Environment error: \(message)"
        }
    }
}
