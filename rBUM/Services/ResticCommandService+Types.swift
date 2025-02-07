//
//  ResticCommandService+Types.swift
//  rBUM
//
//  Created on 7 February 2025.
//

import Foundation

// MARK: - ResticCommand

/// Commands supported by the Restic service
enum ResticCommand: String {
    case `init`
    case backup
    case restore
    case list
}

// MARK: - ResticCommandError

/// Errors that can occur during Restic command execution
public enum ResticCommandError: LocalizedError {
    case resticNotInstalled
    case repositoryNotFound
    case repositoryExists
    case invalidRepository(String)
    case invalidSettings(String)
    case invalidCredentials(String)
    case insufficientPermissions
    case operationNotFound
    case operationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .resticNotInstalled:
            return "Restic is not installed"
        case .repositoryNotFound:
            return "Repository not found"
        case .repositoryExists:
            return "Repository already exists"
        case .invalidRepository(let message):
            return "Invalid repository: \(message)"
        case .invalidSettings(let message):
            return "Invalid settings: \(message)"
        case .invalidCredentials(let message):
            return "Invalid credentials: \(message)"
        case .insufficientPermissions:
            return "Insufficient permissions"
        case .operationNotFound:
            return "Operation not found"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
}
