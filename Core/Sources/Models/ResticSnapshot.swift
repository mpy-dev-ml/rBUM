// 
//  ResticSnapshot.swift
//  rBUM
//
//  Created by Matthew Yeager on 31/01/2025.
//

import Foundation

/// Represents a snapshot in a Restic repository
public struct ResticSnapshot: Codable, Identifiable, Equatable {
    /// Unique identifier of the snapshot
    public let id: String
    /// Time when the snapshot was created
    public let time: Date
    /// Hostname where the snapshot was created
    public let hostname: String
    /// Tags associated with the snapshot
    public let tags: [String]?
    /// Paths included in the snapshot
    public let paths: [String]
    /// Short ID (first 8 characters)
    public var shortId: String {
        String(id.prefix(8))
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case time
        case hostname
        case tags
        case paths
    }
    
    public init(id: String, time: Date, hostname: String, tags: [String]? = nil, paths: [String]) {
        self.id = id
        self.time = time
        self.hostname = hostname
        self.tags = tags
        self.paths = paths
    }
}
