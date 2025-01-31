import Foundation
@testable import rBUM

/// Mock implementation of FileManager for testing
final class MockFileManager: FileManagerProtocol {
    private var files: Set<String> = []
    private var directories: Set<String> = []
    private var error: Error?
    
    /// Reset mock to initial state
    func reset() {
        files = []
        directories = []
        error = nil
    }
    
    /// Set an error to be thrown by operations
    func setError(_ error: Error) {
        self.error = error
    }
    
    /// Add a mock file
    func addFile(at path: String) {
        files.insert(path)
    }
    
    /// Add a mock directory
    func addDirectory(at path: String) {
        directories.insert(path)
    }
    
    // MARK: - Protocol Implementation
    
    func fileExists(atPath path: String) -> Bool {
        files.contains(path)
    }
    
    func directoryExists(at url: URL) -> Bool {
        directories.contains(url.path)
    }
    
    func createDirectory(at url: URL) throws {
        if let error = error { throw error }
        directories.insert(url.path)
    }
    
    func removeItem(at url: URL) throws {
        if let error = error { throw error }
        files.remove(url.path)
        directories.remove(url.path)
    }
    
    func contentsOfDirectory(at url: URL) throws -> [URL] {
        if let error = error { throw error }
        let path = url.path
        let contents = files.union(directories).filter { $0.hasPrefix(path) }
        return contents.map { URL(fileURLWithPath: $0) }
    }
}
