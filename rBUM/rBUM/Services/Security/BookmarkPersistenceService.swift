import Foundation
import os

/// Protocol for persisting and retrieving security-scoped bookmarks
protocol BookmarkPersistenceServiceProtocol {
    /// Persist a bookmark for a URL
    /// - Parameters:
    ///   - data: The bookmark data to persist
    ///   - url: The URL the bookmark is for
    func persistBookmark(_ data: Data, forURL url: URL) async throws
    
    /// Retrieve a bookmark for a URL
    /// - Parameter url: The URL to retrieve the bookmark for
    /// - Returns: The bookmark data if found
    func retrieveBookmark(forURL url: URL) async throws -> Data?
    
    /// Remove a bookmark for a URL
    /// - Parameter url: The URL to remove the bookmark for
    func removeBookmark(forURL url: URL) async throws
    
    /// List all persisted bookmarks
    /// - Returns: Dictionary of URLs and their bookmark data
    func listBookmarks() async throws -> [URL: Data]
}

/// Error types for bookmark persistence operations
enum BookmarkPersistenceError: LocalizedError {
    case persistenceFailed(String)
    case retrievalFailed(String)
    case deletionFailed(String)
    case invalidBookmarkData
    case bookmarkNotFound
    
    var errorDescription: String? {
        switch self {
        case .persistenceFailed(let reason):
            return "Failed to persist bookmark: \(reason)"
        case .retrievalFailed(let reason):
            return "Failed to retrieve bookmark: \(reason)"
        case .deletionFailed(let reason):
            return "Failed to delete bookmark: \(reason)"
        case .invalidBookmarkData:
            return "Invalid bookmark data"
        case .bookmarkNotFound:
            return "Bookmark not found"
        }
    }
}

/// Service for persisting security-scoped bookmarks
final class BookmarkPersistenceService: BookmarkPersistenceServiceProtocol {
    private let fileManager: FileManager
    private let logger: Logger
    
    /// URL where bookmarks are stored
    private var bookmarksDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("rBUM/Bookmarks", isDirectory: true)
    }
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.logger = Logging.logger(for: .bookmarkService)
        Task {
            try? await createBookmarksDirectory()
        }
    }
    
    func persistBookmark(_ data: Data, forURL url: URL) async throws {
        let bookmarkFile = bookmarkFileURL(for: url)
        
        try await Task {
            do {
                try await createBookmarksDirectory()
                try data.write(to: bookmarkFile, options: .atomicWrite)
                logger.info("Persisted bookmark for URL: \(url.path, privacy: .public)")
            } catch {
                logger.error("Failed to persist bookmark: \(error.localizedDescription, privacy: .public)")
                throw BookmarkPersistenceError.persistenceFailed(error.localizedDescription)
            }
        }.value
    }
    
    func retrieveBookmark(forURL url: URL) async throws -> Data? {
        let bookmarkFile = bookmarkFileURL(for: url)
        
        return try await Task {
            guard fileManager.fileExists(atPath: bookmarkFile.path) else {
                return nil
            }
            
            do {
                let data = try Data(contentsOf: bookmarkFile)
                logger.debug("Retrieved bookmark for URL: \(url.path, privacy: .public)")
                return data
            } catch {
                logger.error("Failed to retrieve bookmark: \(error.localizedDescription, privacy: .public)")
                throw BookmarkPersistenceError.retrievalFailed(error.localizedDescription)
            }
        }.value
    }
    
    func removeBookmark(forURL url: URL) async throws {
        let bookmarkFile = bookmarkFileURL(for: url)
        
        try await Task {
            do {
                try fileManager.removeItem(at: bookmarkFile)
                logger.info("Removed bookmark for URL: \(url.path, privacy: .public)")
            } catch {
                logger.error("Failed to remove bookmark: \(error.localizedDescription, privacy: .public)")
                throw BookmarkPersistenceError.deletionFailed(error.localizedDescription)
            }
        }.value
    }
    
    func listBookmarks() async throws -> [URL: Data] {
        return try await Task {
            var bookmarks: [URL: Data] = [:]
            
            do {
                try await createBookmarksDirectory()
                let files = try fileManager.contentsOfDirectory(at: bookmarksDirectory,
                                                              includingPropertiesForKeys: nil,
                                                              options: [.skipsHiddenFiles])
                
                for file in files {
                    if let url = urlFromBookmarkFile(file),
                       let data = try? Data(contentsOf: file) {
                        bookmarks[url] = data
                    }
                }
                
                return bookmarks
            } catch {
                logger.error("Failed to list bookmarks: \(error.localizedDescription, privacy: .public)")
                throw BookmarkPersistenceError.retrievalFailed(error.localizedDescription)
            }
        }.value
    }
    
    // MARK: - Private Methods
    
    private func createBookmarksDirectory() async throws {
        guard !fileManager.fileExists(atPath: bookmarksDirectory.path) else { return }
        
        try await Task {
            do {
                try fileManager.createDirectory(at: bookmarksDirectory,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
                logger.info("Created bookmarks directory")
            } catch {
                logger.error("Failed to create bookmarks directory: \(error.localizedDescription, privacy: .public)")
                throw BookmarkPersistenceError.persistenceFailed("Failed to create bookmarks directory")
            }
        }.value
    }
    
    private func bookmarkFileURL(for url: URL) -> URL {
        let filename = url.absoluteString
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return bookmarksDirectory.appendingPathComponent("\(filename).bookmark")
    }
    
    private func urlFromBookmarkFile(_ file: URL) -> URL? {
        let filename = file.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: "/")
        return URL(string: filename)
    }
}
