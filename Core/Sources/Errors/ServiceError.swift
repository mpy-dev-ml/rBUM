//
//  ServiceError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Errors that can occur during service operations
public enum ServiceError: LocalizedError {
    // General service errors
    case operationFailed
    case notInitialized
    case alreadyInitialized
    case invalidState(String)
    case dependencyError(String)
    
    // Retry-related errors
    case retryFailed(operation: String, underlyingError: Error?)
    
    public var errorDescription: String? {
        switch self {
        case .operationFailed:
            return "The operation failed to complete"
        case .notInitialized:
            return "The service is not initialised"
        case .alreadyInitialized:
            return "The service is already initialised"
        case .invalidState(let state):
            return "Invalid service state: \(state)"
        case .dependencyError(let dependency):
            return "Dependency error: \(dependency)"
        case .retryFailed(let operation, let error):
            if let error = error {
                return "Operation '\(operation)' failed after multiple attempts: \(error.localizedDescription)"
            }
            return "Operation '\(operation)' failed after multiple attempts"
        }
    }
}
