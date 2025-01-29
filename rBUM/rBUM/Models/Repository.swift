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
    
    init(id: UUID = UUID(), name: String, path: URL) {
        self.id = id
        self.name = name
        self.path = path
        self.backupCount = 0
        self.totalSize = 0
    }
}
