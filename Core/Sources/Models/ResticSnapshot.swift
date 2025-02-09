//
//  ResticSnapshot.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 31/01/2025.
//

import Foundation

/// Represents a snapshot in a Restic repository
///
/// A snapshot represents a point-in-time backup of one or more paths in a Restic repository.
/// It contains metadata about the backup including when it was created, what paths were included,
/// and its relationship to other snapshots.
///
/// - Important: Snapshots are immutable once created
@objc public final class ResticSnapshot: NSObject, NSSecureCoding, Codable, Identifiable, Equatable, Hashable {
    public static var supportsSecureCoding: Bool { true }

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

    /// Parent snapshots IDs (for incremental backups)
    public let parent: String?

    /// Total size of the snapshot in bytes
    public let size: UInt64

    /// Repository ID this snapshot belongs to
    public let repositoryId: String

    /// Short ID (first 8 characters)
    public var shortId: String {
        String(id.prefix(8))
    }

    /// Creates a new snapshot instance
    /// - Parameters:
    ///   - id: Unique identifier of the snapshot
    ///   - time: Time when the snapshot was created
    ///   - hostname: Hostname where the snapshot was created
    ///   - tags: Optional tags associated with the snapshot
    ///   - paths: Paths included in the snapshot
    ///   - parent: Optional parent snapshot ID for incremental backups
    ///   - size: Total size of the snapshot in bytes
    ///   - repositoryId: ID of the repository this snapshot belongs to
    public init(
        id: String,
        time: Date,
        hostname: String,
        tags: [String]? = nil,
        paths: [String],
        parent: String? = nil,
        size: UInt64,
        repositoryId: String
    ) {
        self.id = id
        self.time = time
        self.hostname = hostname
        self.tags = tags
        self.paths = paths
        self.parent = parent
        self.size = size
        self.repositoryId = repositoryId
        super.init()
    }

    /// Creates a snapshot from JSON data
    /// - Parameter json: Dictionary containing snapshot data
    /// - Throws: DecodingError if required fields are missing or invalid
    public convenience init(json: [String: Any]) throws {
        guard let id = json["id"] as? String,
              let timeString = json["time"] as? String,
              let hostname = json["hostname"] as? String,
              let paths = json["paths"] as? [String],
              let size = json["size"] as? UInt64,
              let repositoryId = json["repository_id"] as? String else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Missing required fields in snapshot JSON"
                )
            )
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let time = dateFormatter.date(from: timeString) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Invalid date format in snapshot JSON"
                )
            )
        }

        self.init(
            id: id,
            time: time,
            hostname: hostname,
            tags: json["tags"] as? [String],
            paths: paths,
            parent: json["parent"] as? String,
            size: size,
            repositoryId: repositoryId
        )
    }

    public func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(time, forKey: "time")
        coder.encode(hostname, forKey: "hostname")
        coder.encode(tags, forKey: "tags")
        coder.encode(paths, forKey: "paths")
        coder.encode(parent, forKey: "parent")
        coder.encode(size, forKey: "size")
        coder.encode(repositoryId, forKey: "repository_id")
    }

    public required init?(coder: NSCoder) {
        guard let id = coder.decodeObject(
            of: NSString.self,
            forKey: "id"
        ) as String?,
            let time = coder.decodeObject(
                of: NSDate.self,
                forKey: "time"
            ) as Date?,
            let hostname = coder.decodeObject(
                of: NSString.self,
                forKey: "hostname"
            ) as String?,
            let paths = coder.decodeObject(
                of: [NSArray.self, NSString.self],
                forKey: "paths"
            ) as? [String],
            let size = coder.decodeInt64(forKey: "size") as Int64?,
            let repositoryId = coder.decodeObject(
                of: NSString.self,
                forKey: "repository_id"
            ) as String?
        else {
            return nil
        }

        self.id = id
        self.time = time
        self.hostname = hostname
        self.tags = coder.decodeObject(
            of: [NSArray.self, NSString.self],
            forKey: "tags"
        ) as? [String]
        self.paths = paths
        self.parent = coder.decodeObject(
            of: NSString.self,
            forKey: "parent"
        ) as String?
        self.size = UInt64(size)
        self.repositoryId = repositoryId
        super.init()
    }

    // MARK: - Equatable
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ResticSnapshot else { return false }
        return id == other.id &&
               time == other.time &&
               hostname == other.hostname &&
               tags == other.tags &&
               paths == other.paths &&
               parent == other.parent &&
               size == other.size &&
               repositoryId == other.repositoryId
    }
    
    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)
        hasher.combine(time)
        hasher.combine(hostname)
        hasher.combine(tags)
        hasher.combine(paths)
        hasher.combine(parent)
        hasher.combine(size)
        hasher.combine(repositoryId)
        return hasher.finalize()
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        return """
        Snapshot \(shortId)
        Created: \(dateFormatter.string(from: time))
        Host: \(hostname)
        Size: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        Paths: \(paths.joined(separator: ", "))
        \(tags?.isEmpty == false ? "Tags: \(tags!.joined(separator: ", "))" : "")
        """
    }
}
