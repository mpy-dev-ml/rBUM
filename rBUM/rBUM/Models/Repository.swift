//
//  Repository.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation

struct Repository: Identifiable, Codable {
    let id: UUID
    var name: String
    var path: URL
    var lastBackup: Date?
    var backupCount: Int
    var totalSize: Int64
    var createdAt: Date
    var modifiedAt: Date
    
    /// The credentials associated with this repository
    var credentials: RepositoryCredentials {
        RepositoryCredentials(
            repositoryId: id,
            repositoryPath: path.path
        )
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
}

// MARK: - Repository Storage
extension Repository {
    /// The default directory for storing repositories
    static var defaultStorageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("dev.mpy.rBUM", isDirectory: true)
            .appendingPathComponent("Repositories", isDirectory: true) ?? URL(fileURLWithPath: "")
    }
    
    /// Create the default storage directory if it doesn't exist
    static func createDefaultStorageDirectory() throws {
        let directory = defaultStorageDirectory
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}
