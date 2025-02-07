import Foundation

/// Represents the possible states of a service throughout its lifecycle.
/// Services transition between these states as they are initialised,
/// run, encounter errors, and shut down.
public enum ServiceState {
    /// Service has not yet been initialised
    case uninitialized

    /// Service is currently performing initialisation
    case initializing

    /// Service has successfully initialised and is ready for use
    case ready

    /// Service has encountered an error during operation
    case error(Error)

    /// Service has been shut down and is no longer available
    case shutdown
    
    // MARK: - Properties
    
    /// Whether the service is in a usable state
    public var isUsable: Bool {
        switch self {
        case .ready:
            return true
        case .uninitialized, .initializing, .error, .shutdown:
            return false
        }
    }
    
    /// Whether the service has encountered an error
    public var hasError: Bool {
        switch self {
        case .error:
            return true
        case .uninitialized, .initializing, .ready, .shutdown:
            return false
        }
    }
    
    /// The error if the service is in an error state
    public var error: Error? {
        switch self {
        case .error(let error):
            return error
        case .uninitialized, .initializing, .ready, .shutdown:
            return nil
        }
    }
    
    // MARK: - State Transitions
    
    /// Transition to the initializing state
    /// - Returns: New state after transition
    public func transitionToInitializing() -> ServiceState {
        switch self {
        case .uninitialized:
            return .initializing
        case .initializing, .ready, .error, .shutdown:
            return self
        }
    }
    
    /// Transition to the ready state
    /// - Returns: New state after transition
    public func transitionToReady() -> ServiceState {
        switch self {
        case .initializing:
            return .ready
        case .uninitialized, .ready, .error, .shutdown:
            return self
        }
    }
    
    /// Transition to the error state
    /// - Parameter error: Error that caused the transition
    /// - Returns: New state after transition
    public func transitionToError(_ error: Error) -> ServiceState {
        switch self {
        case .uninitialized, .initializing, .ready:
            return .error(error)
        case .error, .shutdown:
            return self
        }
    }
    
    /// Transition to the shutdown state
    /// - Returns: New state after transition
    public func transitionToShutdown() -> ServiceState {
        switch self {
        case .uninitialized, .initializing, .ready, .error:
            return .shutdown
        case .shutdown:
            return self
        }
    }
    
    // MARK: - State Validation
    
    /// Validate if a transition to the given state is allowed
    /// - Parameter state: Target state to transition to
    /// - Returns: True if transition is allowed
    public func canTransitionTo(_ state: ServiceState) -> Bool {
        switch (self, state) {
        case (.uninitialized, .initializing):
            return true
        case (.initializing, .ready):
            return true
        case (_, .error):
            return true
        case (_, .shutdown):
            return true
        default:
            return false
        }
    }
    
    /// Validate if the service can perform operations
    /// - Returns: True if operations are allowed
    public func canPerformOperations() -> Bool {
        switch self {
        case .ready:
            return true
        case .uninitialized, .initializing, .error, .shutdown:
            return false
        }
    }
}
