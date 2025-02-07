import Foundation

/// Protocol defining the lifecycle management capabilities of a service.
/// Conforming types must implement state management and support
/// proper initialisation and shutdown procedures.
///
/// This protocol is essential for services that need to:
/// - Perform setup operations before use
/// - Clean up resources when no longer needed
/// - Track their operational state
/// - Handle errors gracefully
///
/// Example usage:
/// ```swift
/// class MyService: LifecycleManaged {
///     private(set) var state: ServiceState = .uninitialized
///     
///     func initialize() async throws {
///         state = .initializing
///         // Perform setup
///         state = .ready
///     }
///     
///     func shutdown() async {
///         // Clean up resources
///         state = .shutdown
///     }
/// }
/// ```
public protocol LifecycleManaged {
    /// The current state of the service
    var state: ServiceState { get }

    /// Initialises the service and prepares it for use.
    /// This method should be called before any other operations
    /// are performed on the service.
    ///
    /// - Throws: Any error that occurs during initialisation
    func initialize() async throws

    /// Performs an orderly shutdown of the service.
    /// This method should be called when the service is no longer needed
    /// to ensure proper resource cleanup.
    func shutdown() async
}

/// Default implementation of lifecycle management for services that implement logging.
/// This extension provides basic logging of lifecycle events that can be
/// enhanced by concrete implementations.
public extension LifecycleManaged where Self: LoggingService {
    /// Default implementation of service initialisation with logging.
    /// Concrete implementations should override this method to add
    /// their specific initialisation logic.
    ///
    /// - Throws: Any error that occurs during initialisation
    func initialize() async throws {
        logger.info("Initialising service...",
                    file: #file,
                    function: #function,
                    line: #line)
        // Override in concrete implementations
    }

    /// Default implementation of service shutdown with logging.
    /// Concrete implementations should override this method to add
    /// their specific shutdown logic.
    func shutdown() async {
        logger.info("Shutting down service...",
                    file: #file,
                    function: #function,
                    line: #line)
        // Override in concrete implementations
    }
}

/// Extension providing validation methods for lifecycle managed services
public extension LifecycleManaged {
    /// Validate that the service is in a usable state
    /// - Parameter operation: Name of the operation being validated
    /// - Throws: ServiceError if service is not usable
    func validateUsable(for operation: String) throws {
        guard state.isUsable else {
            throw ServiceError.invalidState("Cannot perform \(operation) in state: \(state)")
        }
    }
    
    /// Validate that the service can perform operations
    /// - Parameter operation: Name of the operation being validated
    /// - Throws: ServiceError if operations are not allowed
    func validateCanPerformOperations(for operation: String) throws {
        guard state.canPerformOperations() else {
            throw ServiceError.invalidState("Cannot perform \(operation) in state: \(state)")
        }
    }
    
    /// Validate that the service can transition to a new state
    /// - Parameters:
    ///   - newState: Target state to transition to
    ///   - operation: Name of the operation causing the transition
    /// - Throws: ServiceError if transition is not allowed
    func validateStateTransition(to newState: ServiceState, for operation: String) throws {
        guard state.canTransitionTo(newState) else {
            throw ServiceError.invalidStateTransition("Cannot transition from \(state) to \(newState) during \(operation)")
        }
    }
}
