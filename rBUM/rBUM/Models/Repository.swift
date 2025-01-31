//
//  Repository.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation

/// Represents a Restic backup repository
struct Repository: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String        // Repository display name
    var path: URL          // Local path to repository
    var lastBackup: Date?  // Most recent backup date
    var backupCount: Int   // Number of backups
    var totalSize: Int64   // Total size in bytes
    var createdAt: Date    // Creation timestamp
    var modifiedAt: Date   // Last modified timestamp
    
    /// Keychain service name for repository credentials
    var keychainService: String {
        "dev.mpy.rBUM.repository.\(id.uuidString)"
    }
    
    /// Keychain account name for repository credentials
    var keychainAccount: String {
        path.path
    }
    
    init(id: UUID = UUID(), name: String, path: URL) {
        self.id = id
        self.name = name
        self.path = path
        self.backupCount = 0
        self.totalSize = 0
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Repository, rhs: Repository) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Repository Storage
extension Repository {
    /// The default directory for storing repositories
    static var defaultStorageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Repositories", isDirectory: true)
    }
    
    /// The directory for this repository's data
    var storageDirectory: URL {
        Self.defaultStorageDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }
}
