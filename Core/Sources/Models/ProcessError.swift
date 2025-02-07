//
//  ProcessError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
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
        case let .executionFailed(message):
            "Process execution failed: \(message)"
        case let .invalidExecutable(path):
            "Invalid executable at path: \(path)"
        case let .sandboxViolation(message):
            "Sandbox violation: \(message)"
        case let .timeout(message):
            "Process timed out: \(message)"
        case let .environmentError(message):
            "Environment error: \(message)"
        }
    }
}
