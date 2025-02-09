import Foundation
import os.log
import SwiftUI

@MainActor
public final class RepositoryDiscoveryViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// List of discovered repositories
    @Published private(set) var discoveredRepositories: [DiscoveredRepository] = []
    
    /// Current scanning status
    @Published private(set) var scanningStatus: ScanningStatus = .idle
    
    /// Any error that occurred during operations
    @Published private(set) var error: RepositoryDiscoveryError?
    
    // MARK: - Private Properties
    
    private let discoveryService: RepositoryDiscoveryProtocol
    private let logger: Logger
    
    private var scanTask: Task<Void, Never>?
    
    // MARK: - Types
    
    /// Information about scanning progress
    public struct ScanProgress: Equatable {
        /// Number of items scanned
        public let scannedItems: Int
        /// Number of repositories found
        public let foundRepositories: Int
        
        public init(scannedItems: Int, foundRepositories: Int) {
            self.scannedItems = scannedItems
            self.foundRepositories = foundRepositories
        }
    }
    
    /// Represents the current scanning status
    public enum ScanningStatus: Equatable {
        /// No scanning operation in progress
        case idle
        /// Scanning in progress with progress information
        case scanning(progress: ScanProgress)
        /// Processing discovered repositories
        case processing
        /// Scan completed
        case completed(foundCount: Int)
    }
    
    // MARK: - Initialisation
    
    /// Creates a new repository discovery view model
    /// - Parameters:
    ///   - discoveryService: Service for discovering repositories
    ///   - logger: Logger instance
    public init(
        discoveryService: RepositoryDiscoveryProtocol,
        logger: Logger = Logger(subsystem: "dev.mpy.rBUM", category: "RepositoryDiscovery")
    ) {
        self.discoveryService = discoveryService
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Starts scanning for repositories at the specified URL
    /// - Parameters:
    ///   - url: The URL to scan
    ///   - recursive: Whether to scan subdirectories
    public func startScan(at url: URL, recursive: Bool) {
        guard scanningStatus == .idle else {
            logger.warning("Scan already in progress")
            return
        }
        
        error = nil
        discoveredRepositories = []
        scanningStatus = .scanning(progress: .init(scannedItems: 0, foundRepositories: 0))
        
        scanTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let repositories = try await discoveryService.scanLocation(url, recursive: recursive)
                
                // Update UI with results
                await MainActor.run {
                    self.discoveredRepositories = repositories
                    self.scanningStatus = .completed(foundCount: repositories.count)
                    self.logger.info("Scan completed, found \(repositories.count) repositories")
                }
            } catch {
                await MainActor.run {
                    self.error = error as? RepositoryDiscoveryError ?? .discoveryFailed(error.localizedDescription)
                    self.scanningStatus = .idle
                    self.logger.error("Scan failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Cancels the current scanning operation
    public func cancelScan() {
        logger.info("Cancelling scan")
        scanTask?.cancel()
        discoveryService.cancelDiscovery()
        scanningStatus = .idle
    }
    
    /// Adds a discovered repository to the app for management
    /// - Parameter repository: The repository to add
    public func addRepository(_ repository: DiscoveredRepository) async throws {
        logger.info("Adding repository: \(repository.url.path)")
        
        // First verify the repository
        guard try await discoveryService.verifyRepository(repository) else {
            throw RepositoryDiscoveryError.invalidRepository(repository.url)
        }
        
        // Index the repository for searching
        try await discoveryService.indexRepository(repository)
        
        logger.info("Repository added and indexed successfully")
    }
    
    /// Clears any error state
    public func clearError() {
        error = nil
    }
    
    // MARK: - Deinit
    
    deinit {
        cancelScan()
    }
}
