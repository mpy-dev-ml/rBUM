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

/// Errors that can occur during service operations.
/// This enum provides a comprehensive set of error cases that can occur
/// during service lifecycle and operations, along with recovery suggestions.
public enum ServiceError: LocalizedError {
    // MARK: - Lifecycle Errors
    
    /// Service initialization errors
    case notInitialized(service: String)
    case alreadyInitialized(service: String)
    case initializationFailed(service: String, reason: String)
    
    // MARK: - State Errors
    
    /// Service state errors
    case invalidState(service: String, currentState: String, expectedState: String)
    case stateTransitionFailed(service: String, from: String, to: String)
    case stateLockTimeout(service: String, desiredState: String)
    
    // MARK: - Dependency Errors
    
    /// Service dependency errors
    case dependencyUnavailable(service: String, dependency: String)
    case dependencyMisconfigured(service: String, dependency: String, reason: String)
    case dependencyTimeout(service: String, dependency: String)
    
    // MARK: - Operation Errors
    
    /// Operation execution errors
    case operationFailed(service: String, operation: String, reason: String)
    case operationTimeout(service: String, operation: String, timeout: TimeInterval)
    case operationCancelled(service: String, operation: String)
    
    // MARK: - Resource Errors
    
    /// Resource access and management errors
    case resourceUnavailable(service: String, resource: String)
    case resourceExhausted(service: String, resource: String)
    case resourceLimitExceeded(service: String, resource: String, current: Int, limit: Int)
    
    // MARK: - Retry Errors
    
    /// Retry-related errors
    case retryFailed(
        service: String,
        operation: String,
        attempts: Int,
        underlyingError: Error?
    )
    case retryLimitExceeded(
        service: String,
        operation: String,
        limit: Int
    )
    
    // MARK: - Security Errors
    
    /// Security-related errors
    case authenticationFailed(service: String, reason: String)
    case authorizationFailed(service: String, resource: String)
    case securityViolation(service: String, violation: String)
    
    // MARK: - Error Description
    
    public var errorDescription: String? {
        switch self {
        // Lifecycle Errors
        case .notInitialized(let service):
            return "Service '\(service)' is not initialised"
        case .alreadyInitialized(let service):
            return "Service '\(service)' is already initialised"
        case .initializationFailed(let service, let reason):
            return "Failed to initialize service '\(service)': \(reason)"
            
        // State Errors
        case .invalidState(let service, let current, let expected):
            return """
                Invalid state for service '\(service)':
                Current: \(current)
                Expected: \(expected)
                """
        case .stateTransitionFailed(let service, let from, let to):
            return """
                State transition failed for service '\(service)':
                From: \(from)
                To: \(to)
                """
        case .stateLockTimeout(let service, let state):
            return "Timeout waiting for state '\(state)' in service '\(service)'"
            
        // Dependency Errors
        case .dependencyUnavailable(let service, let dependency):
            return "Dependency '\(dependency)' unavailable for service '\(service)'"
        case .dependencyMisconfigured(let service, let dependency, let reason):
            return """
                Dependency '\(dependency)' misconfigured for service '\(service)':
                \(reason)
                """
        case .dependencyTimeout(let service, let dependency):
            return "Timeout waiting for dependency '\(dependency)' in service '\(service)'"
            
        // Operation Errors
        case .operationFailed(let service, let operation, let reason):
            return """
                Operation '\(operation)' failed in service '\(service)':
                \(reason)
                """
        case .operationTimeout(let service, let operation, let timeout):
            return """
                Operation '\(operation)' timed out in service '\(service)' \
                after \(String(format: "%.1f", timeout))s
                """
        case .operationCancelled(let service, let operation):
            return "Operation '\(operation)' cancelled in service '\(service)'"
            
        // Resource Errors
        case .resourceUnavailable(let service, let resource):
            return "Resource '\(resource)' unavailable for service '\(service)'"
        case .resourceExhausted(let service, let resource):
            return "Resource '\(resource)' exhausted in service '\(service)'"
        case .resourceLimitExceeded(let service, let resource, let current, let limit):
            return """
                Resource limit exceeded in service '\(service)':
                Resource: \(resource)
                Current: \(current)
                Limit: \(limit)
                """
            
        // Retry Errors
        case .retryFailed(let service, let operation, let attempts, let error):
            let errorDesc = error?.localizedDescription ?? "Unknown error"
            return """
                Operation '\(operation)' failed in service '\(service)' \
                after \(attempts) attempts:
                \(errorDesc)
                """
        case .retryLimitExceeded(let service, let operation, let limit):
            return """
                Retry limit (\(limit)) exceeded for operation '\(operation)' \
                in service '\(service)'
                """
            
        // Security Errors
        case .authenticationFailed(let service, let reason):
            return "Authentication failed for service '\(service)': \(reason)"
        case .authorizationFailed(let service, let resource):
            return """
                Authorization failed for service '\(service)' \
                to access resource '\(resource)'
                """
        case .securityViolation(let service, let violation):
            return "Security violation in service '\(service)': \(violation)"
        }
    }
    
    // MARK: - Recovery Suggestion
    
    /// Provides a suggestion for how to recover from this error
    public var recoverySuggestion: String? {
        switch self {
        // Lifecycle Errors
        case .notInitialized:
            return "Initialize the service before using it"
        case .alreadyInitialized:
            return "Deinitialize the service before reinitializing"
        case .initializationFailed:
            return "Check the service configuration and try again"
            
        // State Errors
        case .invalidState:
            return "Ensure the service is in the correct state before proceeding"
        case .stateTransitionFailed:
            return "Check if the state transition is valid and retry"
        case .stateLockTimeout:
            return "Consider increasing the timeout duration or check for deadlocks"
            
        // Dependency Errors
        case .dependencyUnavailable:
            return "Ensure all required dependencies are available and running"
        case .dependencyMisconfigured:
            return "Check the dependency configuration and correct any issues"
        case .dependencyTimeout:
            return "Verify the dependency is responsive and increase timeout if needed"
            
        // Operation Errors
        case .operationFailed:
            return "Check the operation parameters and try again"
        case .operationTimeout:
            return "Consider increasing the operation timeout"
        case .operationCancelled:
            return "Retry the operation if appropriate"
            
        // Resource Errors
        case .resourceUnavailable:
            return "Wait for the resource to become available or use an alternative"
        case .resourceExhausted:
            return "Wait for resources to be freed or increase resource limits"
        case .resourceLimitExceeded:
            return "Reduce resource usage or increase resource limits"
            
        // Retry Errors
        case .retryFailed:
            return "Check the underlying error and adjust retry strategy"
        case .retryLimitExceeded:
            return "Increase retry limit or investigate persistent failures"
            
        // Security Errors
        case .authenticationFailed:
            return "Verify credentials and try again"
        case .authorizationFailed:
            return "Verify permissions and request access if needed"
        case .securityViolation:
            return "Review security policies and ensure compliance"
        }
    }
}
