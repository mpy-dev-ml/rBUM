import Foundation
import Core

/// Protocol for persisting and retrieving security-scoped bookmarks
public protocol BookmarkPersistenceServiceProtocol {
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
public enum BookmarkPersistenceError: LocalizedError {
    case persistenceFailed(String)
    case retrievalFailed(String)
    case deletionFailed(String)
    case invalidBookmarkData
    case bookmarkNotFound
    case sandboxViolation(String)
    
    public var errorDescription: String? {
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
        case .sandboxViolation(let reason):
            return "Sandbox violation: \(reason)"
        }
    }
}

/// Service for persisting security-scoped bookmarks in a sandbox-compliant manner
public final class BookmarkPersistenceService: BookmarkPersistenceServiceProtocol {
    private let fileManager: FileManager
    private let logger: LoggerProtocol
    private let keychain: Keychain
    private let queue: DispatchQueue
    
    /// URL where bookmarks are stored
    private var bookmarksDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("rBUM/Bookmarks", isDirectory: true)
    }
    
    /// Initialize the bookmark persistence service
    /// - Parameters:
    ///   - fileManager: FileManager instance to use
    ///   - logger: Logger instance to use
    ///   - keychain: Keychain instance to use
    public init(
        fileManager: FileManager = .default,
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "BookmarkPersistence"),
        keychain: Keychain = Keychain()
    ) {
        self.fileManager = fileManager
        self.logger = logger
        self.keychain = keychain
        self.queue = DispatchQueue(label: "dev.mpy.rBUM.bookmarkPersistence", qos: .userInitiated)
        
        Task {
            try? await self.createBookmarksDirectory()
        }
    }
    
    public func persistBookmark(_ data: Data, forURL url: URL) async throws {
        try await queue.run {
            self.logger.debug("Saving bookmark", file: #file, function: #function, line: #line)
            
            do {
                let key = self.keychainKey(for: url)
                try self.keychain.save(data, forAccount: key)
                self.logger.info("Successfully saved bookmark", file: #file, function: #function, line: #line)
            } catch {
                self.logger.error("Failed to save bookmark: \(error.localizedDescription)", file: #file, function: #function, line: #line)
                throw BookmarkPersistenceError.persistenceFailed(error.localizedDescription)
            }
        }
    }
    
    public func retrieveBookmark(forURL url: URL) async throws -> Data? {
        try await queue.run {
            self.logger.debug("Retrieving bookmark", file: #file, function: #function, line: #line)
            
            do {
                let key = self.keychainKey(for: url)
                let data = try self.keychain.retrieve(forAccount: key)
                self.logger.info("Successfully retrieved bookmark", file: #file, function: #function, line: #line)
                return data
            } catch KeychainError.retrieveFailed {
                self.logger.info("No bookmark found", file: #file, function: #function, line: #line)
                return nil
            } catch {
                self.logger.error("Failed to retrieve bookmark: \(error.localizedDescription)", file: #file, function: #function, line: #line)
                throw BookmarkPersistenceError.retrievalFailed(error.localizedDescription)
            }
        }
    }
    
    public func removeBookmark(forURL url: URL) async throws {
        try await queue.run {
            self.logger.debug("Removing bookmark", file: #file, function: #function, line: #line)
            
            do {
                let key = self.keychainKey(for: url)
                try self.keychain.delete(forAccount: key)
                self.logger.info("Successfully removed bookmark", file: #file, function: #function, line: #line)
            } catch {
                self.logger.error("Failed to remove bookmark: \(error.localizedDescription)", file: #file, function: #function, line: #line)
                throw BookmarkPersistenceError.deletionFailed(error.localizedDescription)
            }
        }
    }
    
    public func listBookmarks() async throws -> [URL: Data] {
        try await queue.run {
            self.logger.debug("Listing bookmarks", file: #file, function: #function, line: #line)
            
            do {
                let accounts = try self.keychain.listAccounts()
                var bookmarks: [URL: Data] = [:]
                
                for account in accounts {
                    if let url = self.url(fromKey: account),
                       let data = try? self.keychain.retrieve(forAccount: account) {
                        bookmarks[url] = data
                    }
                }
                
                self.logger.info("Successfully listed \(bookmarks.count) bookmarks", file: #file, function: #function, line: #line)
                return bookmarks
            } catch {
                self.logger.error("Failed to list bookmarks: \(error.localizedDescription)", file: #file, function: #function, line: #line)
                throw BookmarkPersistenceError.retrievalFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createBookmarksDirectory() async throws {
        try await queue.run {
            guard !self.fileManager.fileExists(atPath: self.bookmarksDirectory.path) else { return }
            
            do {
                try self.fileManager.createDirectory(at: self.bookmarksDirectory,
                                             withIntermediateDirectories: true,
                                             attributes: nil)
                self.logger.info("Created bookmarks directory", file: #file, function: #function, line: #line)
            } catch {
                self.logger.error("Failed to create bookmarks directory: \(error.localizedDescription)", file: #file, function: #function, line: #line)
                throw BookmarkPersistenceError.persistenceFailed("Failed to create bookmarks directory")
            }
        }
    }
    
    private func keychainKey(for url: URL) -> String {
        "bookmark_\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")"
    }
    
    private func url(fromKey key: String) -> URL? {
        guard key.hasPrefix("bookmark_"),
              let encodedString = key.dropFirst("bookmark_".count).removingPercentEncoding,
              let url = URL(string: encodedString) else {
            return nil
        }
        return url
    }
}

// MARK: - DispatchQueue Extension

private extension DispatchQueue {
    func run<T>(_ block: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            async {
                do {
                    let result = try block()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
