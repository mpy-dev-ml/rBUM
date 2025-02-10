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

/// Class representing a backup snapshot
@objc public class Snapshot: NSObject, NSSecureCoding {
    /// Unique identifier for the snapshot
    @objc public let id: String

    /// Time when the snapshot was created
    @objc public let timestamp: Date

    /// Hostname where the snapshot was created
    @objc public let hostname: String

    /// Tags associated with the snapshot
    @objc public let tags: [String]

    /// Paths included in the snapshot
    @objc public let paths: [String]

    /// Size of the snapshot in bytes
    @objc public let size: Int64

    /// Initialize a new snapshot
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - timestamp: Creation time
    ///   - hostname: Creating host
    ///   - tags: Associated tags
    ///   - paths: Included paths
    ///   - size: Size in bytes
    @objc public init(
        id: String,
        timestamp: Date,
        hostname: String,
        tags: [String],
        paths: [String],
        size: Int64
    ) {
        self.id = id
        self.timestamp = timestamp
        self.hostname = hostname
        self.tags = tags
        self.paths = paths
        self.size = size
        super.init()
    }

    // MARK: - NSSecureCoding

    public static var supportsSecureCoding: Bool { true }

    @objc public func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(timestamp, forKey: "timestamp")
        coder.encode(hostname, forKey: "hostname")
        coder.encode(tags, forKey: "tags")
        coder.encode(paths, forKey: "paths")
        coder.encode(size, forKey: "size")
    }

    @objc public required init?(coder: NSCoder) {
        guard let id = coder.decodeObject(of: NSString.self, forKey: "id") as String?,
              let timestamp = coder.decodeObject(of: NSDate.self, forKey: "timestamp") as Date?,
              let hostname = coder.decodeObject(of: NSString.self, forKey: "hostname") as String?,
              let tags = coder.decodeObject(of: NSArray.self, forKey: "tags") as? [String],
              let paths = coder.decodeObject(of: NSArray.self, forKey: "paths") as? [String]
        else {
            return nil
        }

        self.id = id
        self.timestamp = timestamp
        self.hostname = hostname
        self.tags = tags
        self.paths = paths
        size = coder.decodeInt64(forKey: "size")
        super.init()
    }
}
