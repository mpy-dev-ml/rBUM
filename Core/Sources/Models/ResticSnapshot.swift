//
//  ResticSnapshot.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
// 
//  ResticSnapshot.swift
//  rBUM
//
//  Created by Matthew Yeager on 31/01/2025.
//

import Foundation

/// Represents a snapshot in a Restic repository
@objc public final class ResticSnapshot: NSObject, NSSecureCoding, Identifiable {
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
    /// Short ID (first 8 characters)
    public var shortId: String {
        String(id.prefix(8))
    }
    
    public init(id: String, time: Date, hostname: String, tags: [String]? = nil, paths: [String]) {
        self.id = id
        self.time = time
        self.hostname = hostname
        self.tags = tags
        self.paths = paths
        super.init()
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(time, forKey: "time")
        coder.encode(hostname, forKey: "hostname")
        coder.encode(tags, forKey: "tags")
        coder.encode(paths, forKey: "paths")
    }
    
    public required init?(coder: NSCoder) {
        guard let id = coder.decodeObject(of: NSString.self, forKey: "id") as String?,
              let time = coder.decodeObject(of: NSDate.self, forKey: "time") as Date?,
              let hostname = coder.decodeObject(of: NSString.self, forKey: "hostname") as String?,
              let paths = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "paths") as? [String] else {
            return nil
        }
        
        self.id = id
        self.time = time
        self.hostname = hostname
        self.tags = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "tags") as? [String]
        self.paths = paths
        super.init()
    }
}
