//
//  DevelopmentBookmarkService+Types.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Extension containing type definitions for DevelopmentBookmarkService
@available(macOS 13.0, *)
extension DevelopmentBookmarkService {
    /// Represents a bookmark entry with metadata
    struct BookmarkEntry: Codable {
        let data: Data
        let createdAt: Date
        let lastAccessed: Date
        let accessCount: Int
        var isStale: Bool
        let resourceSize: UInt64
        let resourceType: String
        let permissions: [String]

        static func create(for url: URL) throws -> BookmarkEntry {
            let now = Date()
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .fileResourceTypeKey,
                .posixPermissionsKey
            ])

            return BookmarkEntry(
                data: Data("mock_bookmark_\(url.path)".utf8),
                createdAt: now,
                lastAccessed: now,
                accessCount: 0,
                isStale: false,
                resourceSize: UInt64(resourceValues.fileSize ?? 0),
                resourceType: resourceValues.fileResourceType?.rawValue ?? "unknown",
                permissions: Self.formatPermissions(resourceValues.posixPermissions)
            )
        }

        private static func formatPermissions(_ permissions: Int?) -> [String] {
            guard let perms = permissions else { return [] }
            var result: [String] = []
            if perms & 0o400 != 0 { result.append("read") }
            if perms & 0o200 != 0 { result.append("write") }
            if perms & 0o100 != 0 { result.append("execute") }
            return result
        }

        func accessed() -> BookmarkEntry {
            BookmarkEntry(
                data: data,
                createdAt: createdAt,
                lastAccessed: Date(),
                accessCount: accessCount + 1,
                isStale: isStale,
                resourceSize: resourceSize,
                resourceType: resourceType,
                permissions: permissions
            )
        }

        func markStale() -> BookmarkEntry {
            BookmarkEntry(
                data: data,
                createdAt: createdAt,
                lastAccessed: lastAccessed,
                accessCount: accessCount,
                isStale: true,
                resourceSize: resourceSize,
                resourceType: resourceType,
                permissions: permissions
            )
        }
    }
}
