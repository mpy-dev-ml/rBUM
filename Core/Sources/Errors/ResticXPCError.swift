//
//  ResticXPCError.swift
//  Core
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Foundation

/// Errors that can occur during Restic XPC service operations
public enum ResticXPCError: LocalizedError, Equatable {
    /// The XPC service is not available
    case serviceUnavailable
    
    /// Failed to establish XPC connection
    case connectionFailed
    
    /// Command execution failed with reason
    case executionFailed(String)
    
    /// Invalid security-scoped bookmark for path
    case invalidBookmark(path: String)
    
    /// Security-scoped bookmark is stale for path
    case staleBookmark(path: String)
    
    /// Access denied for path
    case accessDenied(path: String)
    
    /// Operation timed out
    case timeout
    
    /// XPC interface version mismatch
    case interfaceVersionMismatch
    
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Restic XPC service is unavailable"
        case .connectionFailed:
            return "Failed to establish XPC connection"
        case .executionFailed(let reason):
            return "Command execution failed: \(reason)"
        case .invalidBookmark(let path):
            return "Invalid security-scoped bookmark for path: \(path)"
        case .staleBookmark(let path):
            return "Stale security-scoped bookmark for path: \(path)"
        case .accessDenied(let path):
            return "Access denied for path: \(path)"
        case .timeout:
            return "Operation timed out"
        case .interfaceVersionMismatch:
            return "Interface version mismatch"
        }
    }
    
    public static func == (lhs: ResticXPCError, rhs: ResticXPCError) -> Bool {
        switch (lhs, rhs) {
        case (.serviceUnavailable, .serviceUnavailable),
             (.connectionFailed, .connectionFailed),
             (.timeout, .timeout),
             (.interfaceVersionMismatch, .interfaceVersionMismatch):
            return true
        case (.executionFailed(let l), .executionFailed(let r)):
            return l == r
        case (.invalidBookmark(let l), .invalidBookmark(let r)):
            return l == r
        case (.staleBookmark(let l), .staleBookmark(let r)):
            return l == r
        case (.accessDenied(let l), .accessDenied(let r)):
            return l == r
        default:
            return false
        }
    }
}
