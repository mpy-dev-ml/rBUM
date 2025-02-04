//
//  ServiceError.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//


//
//  ServiceError.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Errors that can occur during service operations
public enum ServiceError: LocalizedError {
    case operationFailed
    case notInitialized
    case alreadyInitialized
    case invalidState(String)
    case dependencyError(String)
    
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
        }
    }
}
