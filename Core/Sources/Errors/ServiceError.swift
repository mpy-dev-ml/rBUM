import Foundation

/// An enumeration of errors that can occur during service lifecycle and operations.
///
/// `ServiceError` provides detailed error information for various aspects of
/// service management, including:
/// - Service lifecycle
/// - State management
/// - Dependency handling
/// - Operation execution
/// - Resource management
///
/// Each error case includes relevant context to help with:
/// - Error diagnosis
/// - State recovery
/// - User feedback
/// - System monitoring
///
/// Example usage:
/// ```swift
/// do {
///     try await service.initialize()
/// } catch let error as ServiceError {
///     switch error {
///     case .notInitialized(let service):
///         logger.error("Service not initialised: \(service)")
///     case .dependencyUnavailable(let service, let dependency):
///         logger.error("\(service) missing dependency: \(dependency)")
///     default:
///         logger.error("Service error: \(error.localizedDescription)")
///     }
///
///     if let recovery = error.recoverySuggestion {
///         logger.info("Recovery suggestion: \(recovery)")
///     }
/// }
/// ```
@objc public enum ServiceError: Int, Error {
    // MARK: - Lifecycle Errors

    /// Indicates that a service has not been initialised.
    ///
    /// This error occurs when:
    /// - Service methods are called before initialisation
    /// - Initialisation was skipped
    /// - Previous initialisation failed
    ///
    /// - Parameter service: Name of the service that isn't initialised
    case notInitialized = 1

    /// Indicates that a service is already initialised.
    ///
    /// This error occurs when:
    /// - Attempting to reinitialise a service
    /// - Duplicate initialisation calls
    /// - Race condition in initialisation
    ///
    /// - Parameter service: Name of the service that's already initialised
    case alreadyInitialized = 2

    /// Indicates that service initialisation failed.
    ///
    /// This error occurs when:
    /// - Required resources are unavailable
    /// - Configuration is invalid
    /// - System constraints prevent initialisation
    ///
    /// - Parameters:
    ///   - service: Name of the service that failed to initialise
    ///   - reason: Detailed explanation of the failure
    case initializationFailed = 3

    // MARK: - State Errors

    /// Indicates that a service is in an invalid state.
    ///
    /// This error occurs when:
    /// - Operation requires different state
    /// - State machine violation
    /// - Concurrent state modification
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - currentState: The current state of the service
    ///   - expectedState: The state required for the operation
    case invalidState = 4

    /// Indicates that a state transition failed.
    ///
    /// This error occurs when:
    /// - Invalid transition requested
    /// - Transition preconditions not met
    /// - System prevents transition
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - from: The starting state
    ///   - to: The target state that couldn't be reached
    case stateTransitionFailed = 5

    /// Indicates that acquiring a state lock timed out.
    ///
    /// This error occurs when:
    /// - Lock contention
    /// - Deadlock prevention
    /// - System overload
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - desiredState: The state that couldn't be locked
    case stateLockTimeout = 6

    // MARK: - Dependency Errors

    /// Indicates that a required dependency is unavailable.
    ///
    /// This error occurs when:
    /// - Dependency not found
    /// - Dependency not running
    /// - Dependency crashed
    ///
    /// - Parameters:
    ///   - service: Name of the service requiring the dependency
    ///   - dependency: Name of the unavailable dependency
    case dependencyUnavailable = 7

    /// Indicates that a dependency is misconfigured.
    ///
    /// This error occurs when:
    /// - Invalid configuration
    /// - Version mismatch
    /// - Incompatible settings
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - dependency: Name of the misconfigured dependency
    ///   - reason: Explanation of the misconfiguration
    case dependencyMisconfigured = 8

    /// Indicates that waiting for a dependency timed out.
    ///
    /// This error occurs when:
    /// - Dependency is slow to respond
    /// - Dependency is deadlocked
    /// - System is overloaded
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - dependency: Name of the dependency that timed out
    case dependencyTimeout = 9

    // MARK: - Operation Errors

    /// Indicates that a service operation failed.
    ///
    /// This error occurs when:
    /// - Operation preconditions not met
    /// - Runtime error during execution
    /// - System prevents operation
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - operation: Name of the failed operation
    ///   - reason: Detailed explanation of the failure
    case operationFailed = 10

    /// Indicates that a service operation timed out.
    ///
    /// This error occurs when:
    /// - Operation takes too long
    /// - Resource contention
    /// - System is overloaded
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - operation: Name of the operation that timed out
    ///   - timeout: The duration after which the timeout occurred
    case operationTimeout = 11

    /// Indicates that a service operation was cancelled.
    ///
    /// This error occurs when:
    /// - User cancels operation
    /// - System cancels operation
    /// - Dependent operation fails
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - operation: Name of the cancelled operation
    case operationCancelled = 12

    // MARK: - Resource Errors

    /// Indicates that a required resource is unavailable.
    ///
    /// This error occurs when:
    /// - Resource doesn't exist
    /// - Resource is locked
    /// - System prevents access
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - resource: Name of the unavailable resource
    case resourceUnavailable = 13

    /// Indicates that a resource has been exhausted.
    ///
    /// This error occurs when:
    /// - Resource pool is empty
    /// - No more capacity
    /// - System limits reached
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - resource: Name of the exhausted resource
    case resourceExhausted = 14

    /// Indicates that a resource limit has been exceeded.
    ///
    /// This error occurs when:
    /// - Usage exceeds quota
    /// - Rate limit reached
    /// - System capacity exceeded
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - resource: Name of the resource
    ///   - current: Current usage level
    ///   - limit: Maximum allowed usage
    case resourceLimitExceeded = 15

    // MARK: - Retry Errors

    /// Indicates that a retry attempt failed.
    ///
    /// This error occurs when:
    /// - Maximum retry attempts reached
    /// - Underlying error persists
    /// - System prevents further retries
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - operation: Name of the operation that failed
    ///   - attempts: Number of retry attempts made
    ///   - underlyingError: The underlying error that caused the failure
    case retryFailed = 16

    /// Indicates that the retry limit has been exceeded.
    ///
    /// This error occurs when:
    /// - Maximum retry attempts reached
    /// - Underlying error persists
    /// - System prevents further retries
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - operation: Name of the operation that failed
    ///   - limit: Maximum allowed retry attempts
    case retryLimitExceeded = 17

    // MARK: - Security Errors

    /// Indicates that authentication failed.
    ///
    /// This error occurs when:
    /// - Invalid credentials
    /// - Authentication system failure
    /// - System prevents authentication
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - reason: Detailed explanation of the failure
    case authenticationFailed = 18

    /// Indicates that authorization failed.
    ///
    /// This error occurs when:
    /// - Insufficient permissions
    /// - Authorization system failure
    /// - System prevents access
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - resource: Name of the resource that couldn't be accessed
    case authorizationFailed = 19

    /// Indicates that a security violation occurred.
    ///
    /// This error occurs when:
    /// - Security policy violation
    /// - System compromise
    /// - Unauthorized access
    ///
    /// - Parameters:
    ///   - service: Name of the service
    ///   - violation: Description of the security violation
    case securityViolation = 20

    // MARK: - Error Description

    public var errorDescription: String? {
        switch self {
        // Lifecycle Errors
        case .notInitialized:
            "Service is not initialised"
        case .alreadyInitialized:
            "Service is already initialised"
        case .initializationFailed:
            "Failed to initialize service"
        // State Errors
        case .invalidState:
            "Service is in an invalid state"
        case .stateTransitionFailed:
            "State transition failed"
        case .stateLockTimeout:
            "Timeout waiting for state"
        // Dependency Errors
        case .dependencyUnavailable:
            "Required dependency is unavailable"
        case .dependencyMisconfigured:
            "Dependency is misconfigured"
        case .dependencyTimeout:
            "Timeout waiting for dependency"
        // Operation Errors
        case .operationFailed:
            "Operation failed"
        case .operationTimeout:
            "Operation timed out"
        case .operationCancelled:
            "Operation was cancelled"
        // Resource Errors
        case .resourceUnavailable:
            "Required resource is unavailable"
        case .resourceExhausted:
            "Resource is exhausted"
        case .resourceLimitExceeded:
            "Resource limit exceeded"
        // Retry Errors
        case .retryFailed:
            "Retry attempt failed"
        case .retryLimitExceeded:
            "Retry limit exceeded"
        // Security Errors
        case .authenticationFailed:
            "Authentication failed"
        case .authorizationFailed:
            "Authorization failed"
        case .securityViolation:
            "Security violation occurred"
        }
    }

    // MARK: - Recovery Suggestion

    /// Provides a suggestion for how to recover from this error
    public var recoverySuggestion: String? {
        switch self {
        // Lifecycle Errors
        case .notInitialized:
            "Initialize the service before using it"
        case .alreadyInitialized:
            "Ensure service is not already initialized"
        case .initializationFailed:
            "Check the service configuration and try again"
        // State Errors
        case .invalidState:
            "Reset service to a valid state"
        case .stateTransitionFailed:
            "Check if the state transition is valid and retry"
        case .stateLockTimeout:
            "Consider increasing the timeout duration or check for deadlocks"
        // Dependency Errors
        case .dependencyUnavailable:
            "Ensure all required dependencies are available and running"
        case .dependencyMisconfigured:
            "Check the dependency configuration and correct any issues"
        case .dependencyTimeout:
            "Verify the dependency is responsive and increase timeout if needed"
        // Operation Errors
        case .operationFailed:
            "Check the operation parameters and try again"
        case .operationTimeout:
            "Consider increasing the operation timeout"
        case .operationCancelled:
            "Retry the operation if needed"
        // Resource Errors
        case .resourceUnavailable:
            "Wait for the resource to become available or use an alternative"
        case .resourceExhausted:
            "Wait for resources to be freed or increase resource limits"
        case .resourceLimitExceeded:
            "Reduce resource usage or increase resource limits"
        // Retry Errors
        case .retryFailed:
            "Check the underlying error and adjust retry strategy"
        case .retryLimitExceeded:
            "Increase retry limit or investigate persistent failures"
        // Security Errors
        case .authenticationFailed:
            "Verify credentials and try again"
        case .authorizationFailed:
            "Verify permissions and request access if needed"
        case .securityViolation:
            "Review security policies and ensure compliance"
        }
    }
}
