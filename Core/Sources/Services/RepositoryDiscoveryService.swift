import Foundation
import os.log

/// Service responsible for discovering and managing Restic repositories
public final class RepositoryDiscoveryService: RepositoryDiscoveryProtocol {
    // MARK: - Properties
    
    private let xpcConnection: NSXPCConnection
    private let logger: Logger
    private let securityService: SecurityServiceProtocol
    private let bookmarkStorage: BookmarkStorageProtocol
    
    private var proxy: RepositoryDiscoveryXPCProtocol? {
        xpcConnection.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("XPC connection failed: \(error.localizedDescription)")
        } as? RepositoryDiscoveryXPCProtocol
    }
    
    // MARK: - Initialisation
    
    /// Creates a new repository discovery service
    /// - Parameters:
    ///   - xpcConnection: The XPC connection to use
    ///   - securityService: Service for handling security operations
    ///   - bookmarkStorage: Storage for security-scoped bookmarks
    ///   - logger: Logger instance
    public init(
        xpcConnection: NSXPCConnection,
        securityService: SecurityServiceProtocol,
        bookmarkStorage: BookmarkStorageProtocol,
        logger: Logger = Logger(subsystem: "dev.mpy.rBUM", category: "RepositoryDiscovery")
    ) {
        self.xpcConnection = xpcConnection
        self.securityService = securityService
        self.bookmarkStorage = bookmarkStorage
        self.logger = logger
        
        self.setupXPCConnection()
    }
    
    // MARK: - RepositoryDiscoveryProtocol
    
    public func scanLocation(_ url: URL, recursive: Bool) async throws -> [DiscoveredRepository] {
        logger.info("Starting repository scan at \(url.path)")
        
        guard let bookmark = try? await requestAccessAndCreateBookmark(for: url) else {
            throw RepositoryDiscoveryError.accessDenied(url)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy?.scanLocation(url, recursive: recursive) { urls, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let urls = urls else {
                    continuation.resume(returning: [])
                    return
                }
                
                Task {
                    do {
                        let repositories = try await self.processDiscoveredURLs(urls)
                        continuation.resume(returning: repositories)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    public func verifyRepository(_ repository: DiscoveredRepository) async throws -> Bool {
        logger.info("Verifying repository at \(repository.url.path)")
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy?.verifyRepository(at: repository.url) { isValid, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: isValid)
            }
        }
    }
    
    public func indexRepository(_ repository: DiscoveredRepository) async throws {
        logger.info("Indexing repository at \(repository.url.path)")
        
        try await withCheckedThrowingContinuation { continuation in
            proxy?.indexRepository(at: repository.url) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            }
        }
    }
    
    public func cancelDiscovery() {
        logger.info("Cancelling discovery operations")
        proxy?.cancelOperations()
    }
    
    // MARK: - Private Methods
    
    private func setupXPCConnection() {
        xpcConnection.remoteObjectInterface = NSXPCInterface(with: RepositoryDiscoveryXPCProtocol.self)
        xpcConnection.resume()
    }
    
    private func requestAccessAndCreateBookmark(for url: URL) async throws -> Data {
        // First check if we already have a bookmark
        if let existingBookmark = try? await bookmarkStorage.getBookmark(for: url) {
            return existingBookmark
        }
        
        // Request access and create new bookmark
        guard url.startAccessingSecurityScopedResource() else {
            throw RepositoryDiscoveryError.accessDenied(url)
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        try await bookmarkStorage.storeBookmark(bookmark, for: url)
        return bookmark
    }
    
    private func processDiscoveredURLs(_ urls: [URL]) async throws -> [DiscoveredRepository] {
        var repositories: [DiscoveredRepository] = []
        
        for url in urls {
            guard let metadata = try? await getRepositoryMetadata(for: url) else {
                continue
            }
            
            let repository = DiscoveredRepository(
                url: url,
                type: .local,
                discoveredAt: Date(),
                isVerified: false,
                metadata: metadata
            )
            
            repositories.append(repository)
        }
        
        return repositories
    }
    
    private func getRepositoryMetadata(for url: URL) async throws -> RepositoryMetadata {
        try await withCheckedThrowingContinuation { continuation in
            proxy?.getRepositoryMetadata(at: url) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let metadata = metadata else {
                    continuation.resume(throwing: RepositoryDiscoveryError.invalidRepository(url))
                    return
                }
                
                let repositoryMetadata = RepositoryMetadata(
                    size: metadata["size"] as? UInt64,
                    lastModified: metadata["lastModified"] as? Date,
                    snapshotCount: metadata["snapshotCount"] as? Int
                )
                
                continuation.resume(returning: repositoryMetadata)
            }
        }
    }
}
