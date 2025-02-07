//
//  ServiceError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

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
public enum ServiceError: LocalizedError {
    // MARK: - Lifecycle Errors

    /// Indicates that a service has not been initialised.
    ///
    /// This error occurs when:
    /// - Service methods are called before initialisation
    /// - Initialisation was skipped
    /// - Previous initialisation failed
    ///
    /// - Parameter service: Name of the service that isn't initialised
    case notInitialized(service: String)

    /// Indicates that a service is already initialised.
    ///
    /// This error occurs when:
    /// - Attempting to reinitialise a service
    /// - Duplicate initialisation calls
    /// - Race condition in initialisation
    ///
    /// - Parameter service: Name of the service that's already initialised
    case alreadyInitialized(service: String)

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
    case initializationFailed(service: String, reason: String)

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
    case invalidState(service: String, currentState: String, expectedState: String)

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
    case stateTransitionFailed(service: String, from: String, to: String)

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
    case stateLockTimeout(service: String, desiredState: String)

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
    case dependencyUnavailable(service: String, dependency: String)

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
    case dependencyMisconfigured(service: String, dependency: String, reason: String)

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
    case dependencyTimeout(service: String, dependency: String)

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
    case operationFailed(service: String, operation: String, reason: String)

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
    case operationTimeout(service: String, operation: String, timeout: TimeInterval)

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
    case operationCancelled(service: String, operation: String)

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
    case resourceUnavailable(service: String, resource: String)

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
    case resourceExhausted(service: String, resource: String)

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
    case resourceLimitExceeded(service: String, resource: String, current: Int, limit: Int)

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
    case retryFailed(
        service: String,
        operation: String,
        attempts: Int,
        underlyingError: Error?
    )

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
    case retryLimitExceeded(
        service: String,
        operation: String,
        limit: Int
    )

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
    case authenticationFailed(service: String, reason: String)

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
    case authorizationFailed(service: String, resource: String)

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
    case securityViolation(service: String, violation: String)

    // MARK: - Error Description

    public var errorDescription: String? {
        switch self {
        // Lifecycle Errors
        case let .notInitialized(service):
            return "Service '\(service)' is not initialised"
        case let .alreadyInitialized(service):
            return "Service '\(service)' is already initialised"
        case let .initializationFailed(service, reason):
            return "Failed to initialize service '\(service)': \(reason)"
        // State Errors
        case let .invalidState(service, current, expected):
            return """
            Invalid state for service '\(service)':
            Current: \(current)
            Expected: \(expected)
            """
        case let .stateTransitionFailed(service, from, to):
            return """
            State transition failed for service '\(service)':
            From: \(from)
            To: \(to)
            """
        case let .stateLockTimeout(service, state):
            return "Timeout waiting for state '\(state)' in service '\(service)'"
        // Dependency Errors
        case let .dependencyUnavailable(service, dependency):
            return "Dependency '\(dependency)' unavailable for service '\(service)'"
        case let .dependencyMisconfigured(service, dependency, reason):
            return """
            Dependency '\(dependency)' misconfigured for service '\(service)':
            \(reason)
            """
        case let .dependencyTimeout(service, dependency):
            return "Timeout waiting for dependency '\(dependency)' in service '\(service)'"
        // Operation Errors
        case let .operationFailed(service, operation, reason):
            return """
            Operation '\(operation)' failed in service '\(service)':
            \(reason)
            """
        case let .operationTimeout(service, operation, timeout):
            return """
            Operation '\(operation)' timed out in service '\(service)' \
            after \(String(format: "%.1f", timeout))s
            """
        case let .operationCancelled(service, operation):
            return "Operation '\(operation)' cancelled in service '\(service)'"
        // Resource Errors
        case let .resourceUnavailable(service, resource):
            return "Resource '\(resource)' unavailable for service '\(service)'"
        case let .resourceExhausted(service, resource):
            return "Resource '\(resource)' exhausted in service '\(service)'"
        case let .resourceLimitExceeded(service, resource, current, limit):
            return """
            Resource limit exceeded in service '\(service)':
            Resource: \(resource)
            Current: \(current)
            Limit: \(limit)
            """
        // Retry Errors
        case let .retryFailed(service, operation, attempts, error):
            let errorDesc = error?.localizedDescription ?? "Unknown error"
            return """
            Operation '\(operation)' failed in service '\(service)' \
            after \(attempts) attempts:
            \(errorDesc)
            """
        case let .retryLimitExceeded(service, operation, limit):
            return """
            Retry limit (\(limit)) exceeded for operation '\(operation)' \
            in service '\(service)'
            """
        // Security Errors
        case let .authenticationFailed(service, reason):
            return "Authentication failed for service '\(service)': \(reason)"
        case let .authorizationFailed(service, resource):
            return """
            Authorization failed for service '\(service)' \
            to access resource '\(resource)'
            """
        case let .securityViolation(service, violation):
            return "Security violation in service '\(service)': \(violation)"
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
            "Deinitialize the service before reinitializing"
        case .initializationFailed:
            "Check the service configuration and try again"
        // State Errors
        case .invalidState:
            "Ensure the service is in the correct state before proceeding"
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
            "Retry the operation if appropriate"
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
