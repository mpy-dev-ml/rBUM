//
//  RepositoryCredentials.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Represents the credentials for a Restic repository
public struct RepositoryCredentials: Codable {
    /// Unique identifier for the repository these credentials belong to
    public let repositoryId: UUID
    
    /// Repository password used for encryption
    public var password: String
    
    /// Path to the repository, used as the account identifier in Keychain
    public let repositoryPath: String
    
    /// Optional name of the key file if using key-based authentication
    public var keyFileName: String?
    
    /// Creation date of these credentials
    public let createdAt: Date
    
    /// Last time these credentials were modified
    public var modifiedAt: Date
    
    /// Service name used for Keychain storage
    public var keychainService: String {
        "dev.mpy.rBUM.repository.\(repositoryId.uuidString)"
    }
    
    /// Account name used for Keychain storage
    public var keychainAccount: String {
        repositoryPath
    }
    
    public init(
        repositoryId: UUID,
        password: String,
        repositoryPath: String,
        keyFileName: String? = nil
    ) {
        self.repositoryId = repositoryId
        self.password = password
        self.repositoryPath = repositoryPath
        self.keyFileName = keyFileName
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    public mutating func updatePassword(_ newPassword: String) {
        password = newPassword
        modifiedAt = Date()
    }
}

// MARK: - Equatable
extension RepositoryCredentials: Equatable {
    public static func == (lhs: RepositoryCredentials, rhs: RepositoryCredentials) -> Bool {
        // Only compare the identifying properties, not timestamps
        lhs.repositoryId == rhs.repositoryId &&
        lhs.password == rhs.password &&
        lhs.repositoryPath == rhs.repositoryPath &&
        lhs.keyFileName == rhs.keyFileName
    }
}
