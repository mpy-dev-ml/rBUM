import Foundation
import Core

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
    private let logger: LoggerProtocol
    private let keychain: Keychain
    
    /// URL where bookmarks are stored
    private var bookmarksDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("rBUM/Bookmarks", isDirectory: true)
    }
    
    init(fileManager: FileManager = .default, logger: LoggerProtocol = LoggerFactory.createLogger(category: "BookmarkPersistence"), keychain: Keychain = Keychain()) {
        self.fileManager = fileManager
        self.logger = logger
        self.keychain = keychain
        Task {
            try? await createBookmarksDirectory()
        }
    }
    
    func persistBookmark(_ data: Data, forURL url: URL) async throws {
        logger.debug("Saving bookmark for URL: \(url.path, privacy: .private)")
        
        do {
            let key = url.path
            try await keychain.set(data, for: key)
            logger.info("Successfully saved bookmark for: \(url.path, privacy: .private)")
        } catch {
            logger.error("Failed to save bookmark: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }
    
    func retrieveBookmark(forURL url: URL) async throws -> Data? {
        logger.debug("Loading bookmark for URL: \(url.path, privacy: .private)")
        
        do {
            let key = url.path
            guard let data = try await keychain.get(key) else {
                logger.error("No bookmark found for URL: \(url.path, privacy: .private)")
                throw BookmarkPersistenceError.bookmarkNotFound
            }
            
            logger.info("Successfully loaded bookmark for: \(url.path, privacy: .private)")
            return data
            
        } catch {
            logger.error("Failed to load bookmark: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }
    
    func removeBookmark(forURL url: URL) async throws {
        logger.debug("Deleting bookmark for URL: \(url.path, privacy: .private)")
        
        do {
            let key = url.path
            try await keychain.delete(key)
            logger.info("Successfully deleted bookmark for: \(url.path, privacy: .private)")
        } catch {
            logger.error("Failed to delete bookmark: \(error.localizedDescription, privacy: .private)")
            throw error
        }
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
