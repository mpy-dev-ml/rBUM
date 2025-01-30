//
//  Snapshot.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

struct Snapshot: Identifiable, Codable, Hashable {
    let id: String
    let time: Date
    let hostname: String
    let username: String
    let paths: [String]
    let tags: [String]
    let sizeInBytes: Int64
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case time = "time"
        case hostname = "hostname"
        case username = "username"
        case paths = "paths"
        case tags = "tags"
        case sizeInBytes = "size_bytes"
    }
    
    init(id: String, time: Date, hostname: String, username: String, paths: [String], tags: [String], sizeInBytes: Int64) {
        self.id = id
        self.time = time
        self.hostname = hostname
        self.username = username
        self.paths = paths
        self.tags = tags
        self.sizeInBytes = sizeInBytes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        
        // Handle restic's RFC3339 timestamp format
        let timeString = try container.decode(String.self, forKey: .time)
        guard let parsedTime = ISO8601DateFormatter().date(from: timeString) else {
            throw DecodingError.dataCorruptedError(forKey: .time, in: container, debugDescription: "Invalid date format")
        }
        time = parsedTime
        
        hostname = try container.decode(String.self, forKey: .hostname)
        username = try container.decode(String.self, forKey: .username)
        paths = try container.decode([String].self, forKey: .paths)
        tags = try container.decode([String].self, forKey: .tags)
        sizeInBytes = try container.decode(Int64.self, forKey: .sizeInBytes)
    }
    
    func formattedSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }
}
