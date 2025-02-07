//
//  Snapshot.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Represents a Restic backup snapshot
public struct Snapshot: Codable, Identifiable, Equatable {
    /// Unique identifier for the snapshot
    public let id: String

    /// Time when the snapshot was created
    public let time: Date

    /// Repository this snapshot belongs to
    public let repository: Repository

    /// Optional tags associated with the snapshot
    public let tags: [String]?

    /// Creates a new snapshot
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - time: Creation time
    ///   - repository: Source repository
    ///   - tags: Optional tags
    public init(id: String, time: Date, repository: Repository, tags: [String]? = nil) {
        self.id = id
        self.time = time
        self.repository = repository
        self.tags = tags
    }
}
