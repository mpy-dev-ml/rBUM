//
//  BackupSource.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Represents a source location for backup
public struct BackupSource: Codable, Equatable {
    /// The path to the source directory or file
    public let path: URL
    
    /// Whether to include subdirectories
    public let includeSubdirectories: Bool
    
    /// File patterns to include (e.g., "*.txt", "*.jpg")
    public let includePatterns: [String]
    
    /// File patterns to exclude (e.g., "*.tmp", "*.log")
    public let excludePatterns: [String]
    
    /// Creates a new backup source
    /// - Parameters:
    ///   - path: The path to the source directory or file
    ///   - includeSubdirectories: Whether to include subdirectories
    ///   - includePatterns: File patterns to include
    ///   - excludePatterns: File patterns to exclude
    public init(
        path: URL,
        includeSubdirectories: Bool = true,
        includePatterns: [String] = [],
        excludePatterns: [String] = []
    ) {
        self.path = path
        self.includeSubdirectories = includeSubdirectories
        self.includePatterns = includePatterns
        self.excludePatterns = excludePatterns
    }
    
    /// Creates a backup source for a directory
    /// - Parameters:
    ///   - path: The path to the directory
    ///   - includeSubdirectories: Whether to include subdirectories
    /// - Returns: A new backup source
    public static func directory(_ path: URL, includeSubdirectories: Bool = true) -> BackupSource {
        BackupSource(path: path, includeSubdirectories: includeSubdirectories)
    }
    
    /// Creates a backup source for specific file types
    /// - Parameters:
    ///   - path: The path to search
    ///   - extensions: File extensions to include (without the dot)
    /// - Returns: A new backup source
    public static func fileTypes(_ path: URL, extensions: [String]) -> BackupSource {
        let patterns = extensions.map { "*.\($0)" }
        return BackupSource(path: path, includePatterns: patterns)
    }
}
