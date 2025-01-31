import Foundation

/// Protocol defining file management operations
protocol FileManagerProtocol {
    /// Check if a file exists at the given path
    /// - Parameter path: Path to check
    /// - Returns: True if file exists
    func fileExists(atPath path: String) -> Bool
    
    /// Check if a directory exists at the given URL
    /// - Parameter url: URL to check
    /// - Returns: True if directory exists
    func directoryExists(at url: URL) -> Bool
    
    /// Create a directory at the given URL
    /// - Parameter url: URL where to create directory
    func createDirectory(at url: URL) throws
    
    /// Remove an item at the given URL
    /// - Parameter url: URL of item to remove
    func removeItem(at url: URL) throws
    
    /// Get contents of directory at the given URL
    /// - Parameter url: URL of directory
    /// - Returns: Array of URLs for directory contents
    func contentsOfDirectory(at url: URL) throws -> [URL]
}
