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
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.mpy.rBUM", 
                           category: "Storage")
        
        // Create application support directory if needed
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appFolder = appSupportURL.appendingPathComponent(appFolderName)
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
    }
    
    func save(_ repository: Repository) throws {
        var repositories = try list()
        
        // Update or add repository
        if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
            repositories[index] = repository
        } else {
            repositories.append(repository)
        }
        
        // Save repository data
        let data = try JSONEncoder().encode(repositories)
        try data.write(to: storageURL)
        
        // Create and save security-scoped bookmark
        if let url = URL(string: repository.path) {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            var bookmarks = try loadBookmarks()
            bookmarks[repository.id] = bookmark
            try saveBookmarks(bookmarks)
        }
        
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
            if let bookmark = try loadBookmarks()[repository.id],
               let url = try? URL(resolvingBookmarkData: bookmark,
                                options: .withSecurityScope,
                                relativeTo: nil,
                                bookmarkDataIsStale: nil) {
                url.startAccessingSecurityScopedResource()
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
}
