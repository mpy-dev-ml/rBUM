//
//  SnapshotListViewModel.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import SwiftUI
import Core

/// Manages the list of snapshots for a repository
@MainActor
final class SnapshotListViewModel: ObservableObject {
    // MARK: - Types
    
    enum Filter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
        case tagged = "Tagged"
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var repository: Repository
    @Published private(set) var snapshots: [ResticSnapshot] = []
    @Published private(set) var progress: ProgressTracker?
    @Published var error: Error?
    @Published var showError = false
    @Published var selectedSnapshot: ResticSnapshot?
    @Published var showRestoreSheet = false
    @Published var restorePath: URL?
    @Published var searchText = ""
    @Published var selectedFilter: Filter = .all
    
    // MARK: - Private Properties
    
    private let repositoryService: RepositoryServiceProtocol
    private let credentialsService: CredentialsServiceProtocol
    private let securityService: SecurityServiceProtocol
    private let bookmarkService: BookmarkServiceProtocol
    private let logger: LoggerProtocol
    private let calendar = Calendar.current
    
    // MARK: - Initialization
    
    init(
        repository: Repository,
        repositoryService: RepositoryServiceProtocol = RepositoryService(),
        credentialsService: CredentialsServiceProtocol = CredentialsService(),
        securityService: SecurityServiceProtocol = SecurityService(),
        bookmarkService: BookmarkServiceProtocol = BookmarkService(),
        logger: LoggerProtocol = Logging.logger(for: .snapshots)
    ) {
        self.repository = repository
        self.repositoryService = repositoryService
        self.credentialsService = credentialsService
        self.securityService = securityService
        self.bookmarkService = bookmarkService
        self.logger = logger
        
        logger.debug("Initialized SnapshotListViewModel for repository: \(repository.id)", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    // MARK: - Public Methods
    
    /// Load snapshots from the repository
    func loadSnapshots() async {
        logger.debug("Loading snapshots for repository: \(repository.id)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Create progress tracker
            let tracker = ProgressTracker(total: 1)
            self.progress = tracker
            
            // Get repository credentials
            let credentials = try await credentialsService.retrieveCredentials(for: repository)
            
            // List snapshots
            let status = try await repositoryService.listSnapshots(repository, credentials: credentials)
            
            // Update snapshots
            snapshots = status.snapshots.sorted { $0.time > $1.time }
            
            // Complete progress
            progress?.complete()
            
            logger.info("Loaded \(snapshots.count) snapshots from repository: \(repository.id)", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            progress?.fail(error)
            self.error = error
            showError = true
            logger.error("Failed to load snapshots: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
        }
    }
    
    /// Delete a snapshot
    /// - Parameter snapshot: The snapshot to delete
    func deleteSnapshot(_ snapshot: ResticSnapshot) async {
        logger.debug("Deleting snapshot: \(snapshot.id)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Create progress tracker
            let tracker = ProgressTracker(total: 1)
            self.progress = tracker
            
            // Get repository credentials
            let credentials = try await credentialsService.retrieveCredentials(for: repository)
            
            // Delete snapshot
            try await repositoryService.deleteSnapshot(snapshot, from: repository, credentials: credentials)
            
            // Complete progress
            progress?.complete()
            
            // Refresh snapshots
            await loadSnapshots()
            
            logger.info("Successfully deleted snapshot: \(snapshot.id)", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            progress?.fail(error)
            self.error = error
            showError = true
            logger.error("Failed to delete snapshot: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
        }
    }
    
    /// Restore a snapshot
    /// - Parameters:
    ///   - snapshot: The snapshot to restore
    ///   - path: The path to restore to
    func restoreSnapshot(_ snapshot: ResticSnapshot, to path: URL) async {
        logger.debug("Restoring snapshot \(snapshot.id) to \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Create progress tracker
            let tracker = ProgressTracker(total: Int64(snapshot.paths.count))
            self.progress = tracker
            
            // Validate restore path access
            try securityService.validateAccess(to: path)
            
            // Get repository credentials
            let credentials = try await credentialsService.retrieveCredentials(for: repository)
            
            // Create bookmark for restore path
            try bookmarkService.createBookmark(for: path)
            
            // Start restore
            try await repositoryService.restoreSnapshot(
                snapshot,
                to: path,
                from: repository,
                credentials: credentials,
                onProgress: { [weak self] processed in
                    self?.progress?.update(processed: Int64(processed))
                }
            )
            
            // Complete progress
            progress?.complete()
            
            logger.info("Successfully restored snapshot \(snapshot.id) to \(path.path)", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            progress?.fail(error)
            self.error = error
            showError = true
            logger.error("Failed to restore snapshot: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Filtered snapshots based on search text and selected filter
    var filteredSnapshots: [ResticSnapshot] {
        snapshots.filter { snapshot in
            // Apply search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let nameMatch = snapshot.hostname.lowercased().contains(searchLower)
                let pathMatch = snapshot.paths.contains { $0.lowercased().contains(searchLower) }
                let tagMatch = snapshot.tags?.contains { $0.lowercased().contains(searchLower) } ?? false
                
                guard nameMatch || pathMatch || tagMatch else {
                    return false
                }
            }
            
            // Apply time filter
            switch selectedFilter {
            case .all:
                return true
            case .today:
                return calendar.isDateInToday(snapshot.time)
            case .thisWeek:
                return calendar.isDate(snapshot.time, equalTo: Date(), toGranularity: .weekOfYear)
            case .thisMonth:
                return calendar.isDate(snapshot.time, equalTo: Date(), toGranularity: .month)
            case .thisYear:
                return calendar.isDate(snapshot.time, equalTo: Date(), toGranularity: .year)
            case .tagged:
                return !(snapshot.tags?.isEmpty ?? true)
            }
        }
    }
    
    var groupedSnapshots: [(String, [ResticSnapshot])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSnapshots) { snapshot in
            calendar.startOfDay(for: snapshot.time)
        }
        
        return grouped.map { (date, snapshots) in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return (formatter.string(from: date), snapshots)
        }.sorted { $0.0 > $1.0 }
    }
    
    var uniqueTags: [String] {
        Array(Set(snapshots.flatMap(\.tags))).sorted()
    }
}

// Add sandbox-specific error types
extension RepositoryError {
    static func sandboxViolation(_ message: String) -> RepositoryError {
        .operationFailed("Sandbox violation: \(message)")
    }
    
    static func bookmarkError(_ message: String) -> RepositoryError {
        .operationFailed("Bookmark error: \(message)")
    }
}
