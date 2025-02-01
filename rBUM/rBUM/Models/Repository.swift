//
//  Repository.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation

/// Represents a Restic backup repository
public struct Repository: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String        // Repository display name
    public var path: URL          // Local path to repository
    public var lastBackup: Date?  // Most recent backup date
    public var backupCount: Int   // Number of backups
    public var totalSize: Int64   // Total size in bytes
    public var createdAt: Date    // Creation timestamp
    public var modifiedAt: Date   // Last modified timestamp
    public let credentials: RepositoryCredentials  // Repository credentials
    
    /// Keychain service name for repository credentials
    public var keychainService: String {
        "dev.mpy.rBUM.repository.\(id.uuidString)"
    }
    
    /// Keychain account name for repository credentials
    public var keychainAccount: String {
        path.path
    }
    
    public init(id: UUID = UUID(), name: String, path: URL, credentials: RepositoryCredentials) {
        self.id = id
        self.name = name
        self.path = path
        self.credentials = credentials
        self.backupCount = 0
        self.totalSize = 0
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Repository, rhs: Repository) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Repository Storage
extension Repository {
    /// The default directory for storing repositories
    public static var defaultStorageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Repositories", isDirectory: true)
    }
    
    /// The directory for this repository's data
    public var storageDirectory: URL {
        Self.defaultStorageDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }
}
