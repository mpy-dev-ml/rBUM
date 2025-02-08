//
//  BackupListViewModel.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Core
import Foundation
import SwiftUI

/// View model for managing the list of backups across all repositories
@MainActor
final class BackupListViewModel: ObservableObject {
    // MARK: - Types
    
    /// Represents the state of a backup operation
    enum BackupState {
        case idle
        case inProgress(progress: Double)
        case completed(date: Date)
        case failed(error: Error)
    }
    
    /// Represents a backup operation with its associated data
    struct BackupOperation: Identifiable {
        let id: String
        let repository: Repository
        let sources: [URL]
        let tags: [String]
        let startTime: Date
        var state: BackupState
        var lastUpdated: Date
    }
    
    // MARK: - Published Properties
    
    /// List of all backup operations
    @Published private(set) var backupOperations: [BackupOperation] = []
    
    /// List of available repositories
    @Published private(set) var repositories: [Repository] = []
    
    /// Currently selected backup operation
    @Published var selectedOperation: BackupOperation?
    
    /// Whether to show the new backup sheet
    @Published var showNewBackupSheet = false
    
    /// Filter for backup operations
    @Published var filter: Filter = .all
    
    /// Search text for filtering operations
    @Published var searchText = ""
    
    // MARK: - Private Properties
    
    private let backupService: BackupServiceProtocol
    private let repositoryService: RepositoryServiceProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    /// Initialize the view model with required services
    /// - Parameters:
    ///   - backupService: Service for managing backup operations
    ///   - repositoryService: Service for accessing repositories
    ///   - logger: Logger for recording events
    init(
        backupService: BackupServiceProtocol,
        repositoryService: RepositoryServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.backupService = backupService
        self.repositoryService = repositoryService
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Load all backup operations and repositories
    func loadBackupOperations() async {
        do {
            async let repos = repositoryService.listRepositories()
            async let snapshots = repositories.first.map { try await backupService.listSnapshots(in: $0) } ?? []
            
            let (loadedRepos, loadedSnapshots) = try await (repos, snapshots)
            
            await MainActor.run {
                repositories = loadedRepos
                backupOperations = loadedSnapshots.map { snapshot in
                    BackupOperation(
                        id: snapshot.id,
                        repository: repositories.first ?? Repository(name: "Unknown", url: nil),
                        sources: [], // TODO: Add source tracking
                        tags: snapshot.tags,
                        startTime: snapshot.time,
                        state: .completed(date: snapshot.time),
                        lastUpdated: snapshot.time
                    )
                }
            }
        } catch {
            logger.error("Failed to load backup operations: \(error.localizedDescription)")
        }
    }
    
    /// Start a new backup operation
    /// - Parameters:
    ///   - repository: Repository to backup to
    ///   - sources: Source URLs to backup
    ///   - tags: Optional tags for the backup
    func startBackup(
        to repository: Repository,
        sources: [URL],
        tags: [String]
    ) async {
        do {
            try await backupService.createBackup(
                to: repository,
                paths: sources.map(\.path),
                tags: tags
            )
            
            // Refresh the list after creating a backup
            await loadBackupOperations()
        } catch {
            logger.error("Failed to start backup: \(error.localizedDescription)")
        }
    }
    
    /// Cancel a backup operation
    /// - Parameter operation: The operation to cancel
    func cancelBackup(_ operation: BackupOperation) async {
        // TODO: Implement cancellation when supported by BackupService
        logger.warning("Backup cancellation not yet implemented")
    }
    
    // MARK: - Private Methods
    
    private func mapBackupState(_ state: BackupState) -> BackupState {
        state
    }
}

// MARK: - Filter

extension BackupListViewModel {
    /// Filter options for backup operations
    enum Filter: String, CaseIterable {
        case all = "All"
        case inProgress = "In Progress"
        case completed = "Completed"
        case failed = "Failed"
        
        var predicate: (BackupOperation) -> Bool {
            switch self {
            case .all:
                return { _ in true }
            case .inProgress:
                return { operation in
                    if case .inProgress = operation.state {
                        return true
                    }
                    return false
                }
            case .completed:
                return { operation in
                    if case .completed = operation.state {
                        return true
                    }
                    return false
                }
            case .failed:
                return { operation in
                    if case .failed = operation.state {
                        return true
                    }
                    return false
                }
            }
        }
    }
}
