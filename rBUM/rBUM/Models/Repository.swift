//
//  Repository.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation

struct Repository: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: URL
    var lastBackup: Date?
    var backupCount: Int
    var totalSize: Int64
    var createdAt: Date
    var modifiedAt: Date
    
    /// The keychain service name for this repository
    var keychainService: String {
        "dev.mpy.rBUM.repository.\(id.uuidString)"
    }
    
    /// The keychain account name for this repository
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
