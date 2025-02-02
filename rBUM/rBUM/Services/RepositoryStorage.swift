import Foundation
import os

protocol RepositoryStorageProtocol {
    func save(_ repository: Repository) throws
    func list() throws -> [Repository]
    func delete(_ repository: Repository) throws
    func get(forId id: String) throws -> Repository?
}

/// Manages persistent storage of repository information and security-scoped bookmarks
final class RepositoryStorage: RepositoryStorageProtocol {
    private let fileManager: FileManager
    private let logger: Logger
    private let bookmarkService: BookmarkServiceProtocol
    private let appFolderName = "dev.mpy.rBUM"
    
    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent(appFolderName)
        return appFolder.appendingPathComponent("repositories.json")
    }
    
    private var bookmarksURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent(appFolderName)
        return appFolder.appendingPathComponent("bookmarks.plist")
    }
    
    init(fileManager: FileManager = .default, 
         bookmarkService: BookmarkServiceProtocol = BookmarkService()) {
        self.fileManager = fileManager
        self.bookmarkService = bookmarkService
        self.logger = Logging.logger(for: .storage)
        
        // Create application support directory if needed
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appFolder = appSupportURL.appendingPathComponent(appFolderName)
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
    }
    
    func save(_ repository: Repository) throws {
        var repositories = try list()
        
        // Create security-scoped bookmark for the repository
        if let url = URL(string: repository.path) {
            do {
                let bookmarkData = try bookmarkService.createBookmark(for: url)
                var bookmarks = try loadBookmarks()
                bookmarks[repository.id] = bookmarkData
                try saveBookmarks(bookmarks)
            } catch {
                logger.error("Failed to create bookmark for repository: \(repository.id, privacy: .public)")
                throw RepositoryStorageError.bookmarkCreationFailed(error.localizedDescription)
            }
        }
        
        // Update repositories list
        if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
            repositories[index] = repository
        } else {
            repositories.append(repository)
        }
        
        // Save updated repository list
        let data = try JSONEncoder().encode(repositories)
        try data.write(to: storageURL)
        
        logger.info("\(repository.id, privacy: .public)")
    }
    
    func list() throws -> [Repository] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: storageURL)
        let repositories = try JSONDecoder().decode([Repository].self, from: data)
        
        // Start accessing security-scoped resources
        for repository in repositories {
            if let bookmark = try loadBookmarks()[repository.id] {
                do {
                    let (url, isStale) = try bookmarkService.resolveBookmark(bookmark)
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    if !hasAccess {
                        logger.error("Sandbox access denied for repository: \(repository.id, privacy: .public). User may need to re-authorize access.")
                        continue
                    }
                    
                    if isStale {
                        try refreshBookmark(for: repository, url: url)
                    }
                } catch {
                    logger.error("Failed to resolve bookmark for repository: \(repository.id, privacy: .public)")
                }
            }
        }
        
        return repositories
    }
    
    func delete(_ repository: Repository) throws {
        var repositories = try list()
        repositories.removeAll { $0.id == repository.id }
        
        // Save updated repository list
        let data = try JSONEncoder().encode(repositories)
        try data.write(to: storageURL)
        
        // Remove bookmark
        var bookmarks = try loadBookmarks()
        bookmarks.removeValue(forKey: repository.id)
        try saveBookmarks(bookmarks)
        
        logger.info("\(repository.id, privacy: .public)")
    }
    
    func get(forId id: String) throws -> Repository? {
        let repositories = try list()
        return repositories.first { $0.id == id }
    }
    
    // MARK: - Private Methods
    
    private func loadBookmarks() throws -> [String: Data] {
        guard fileManager.fileExists(atPath: bookmarksURL.path) else {
            return [:]
        }
        
        let data = try Data(contentsOf: bookmarksURL)
        return try PropertyListDecoder().decode([String: Data].self, from: data)
    }
    
    private func saveBookmarks(_ bookmarks: [String: Data]) throws {
        let data = try PropertyListEncoder().encode(bookmarks)
        try data.write(to: bookmarksURL)
    }
    
    private func refreshBookmark(for repository: Repository, url: URL) throws {
        logger.info("Refreshing stale bookmark for repository: \(repository.id, privacy: .public)")
        
        do {
            // Create new bookmark data with security scope
            let newBookmarkData = try bookmarkService.refreshBookmark(for: url)
            
            // Update bookmarks dictionary
            var bookmarks = try loadBookmarks()
            bookmarks[repository.id] = newBookmarkData
            
            // Save updated bookmarks
            try saveBookmarks(bookmarks)
            
            logger.info("Successfully refreshed bookmark for repository: \(repository.id, privacy: .public)")
        } catch {
            logger.error("Failed to refresh bookmark: \(error.localizedDescription, privacy: .public)")
            throw RepositoryStorageError.bookmarkUpdateFailed(error.localizedDescription)
        }
    }
    
    /// Error types specific to repository storage operations
    enum RepositoryStorageError: LocalizedError {
        case bookmarkCreationFailed(String)
        case bookmarkUpdateFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .bookmarkCreationFailed(let reason):
                return "Failed to create bookmark: \(reason)"
            case .bookmarkUpdateFailed(let reason):
                return "Failed to update bookmark: \(reason)"
            }
        }
    }
}
