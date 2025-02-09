import Foundation

/// Represents the current state of an XPC connection
public enum XPCConnectionState: Equatable {
    /// Connection is active and healthy
    case active
    
    /// Connection is being established
    case connecting
    
    /// Connection has been interrupted
    case interrupted(Date)
    
    /// Connection has been invalidated
    case invalidated(Date)
    
    /// Connection is in recovery
    case recovering(attempt: Int, since: Date)
    
    /// Connection has failed permanently
    case failed(Error)
    
    /// Whether the connection is in a state that allows recovery
    var canRecover: Bool {
        switch self {
        case .interrupted, .invalidated:
            return true
        case .recovering(let attempt, _):
            return attempt < XPCConnectionState.maxRecoveryAttempts
        default:
            return false
        }
    }
    
    /// Maximum number of recovery attempts before considering the connection failed
    static let maxRecoveryAttempts = 3
    
    /// Delay between recovery attempts in seconds
    static let recoveryDelay: TimeInterval = 2.0
    
    /// Maximum time to wait for recovery before failing
    static let recoveryTimeout: TimeInterval = 30.0
}

/// Protocol for tracking XPC connection state changes
public protocol XPCConnectionStateDelegate: AnyObject {
    /// Called when the connection state changes
    /// - Parameters:
    ///   - oldState: Previous connection state
    ///   - newState: New connection state
    func connectionStateDidChange(from oldState: XPCConnectionState, to newState: XPCConnectionState)
}
