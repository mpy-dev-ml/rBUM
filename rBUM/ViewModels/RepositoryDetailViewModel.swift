//
//  RepositoryDetailViewModel.swift
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
import os.log

@MainActor
final class RepositoryDetailViewModel: ObservableObject {
    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case snapshots = "Snapshots"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .overview:
                return "info.circle"
            case .snapshots:
                return "clock"
            case .settings:
                return "gear"
            }
        }
    }
    
    // MARK: - Properties
    
    @Published var selectedTab: Tab = .overview
    @Published var repository: Repository
    @Published var snapshots: [ResticSnapshot] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let repositoryService: RepositoryServiceProtocol
    private let logger: Logger
    
    // MARK: - Initialization
    
    init(
        repository: Repository,
        repositoryService: RepositoryServiceProtocol,
        logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "repository-detail")
    ) {
        self.repository = repository
        self.repositoryService = repositoryService
        self.logger = logger
        
        logger.debug("Viewing repository details")
    }
    
    // MARK: - Repository Operations
    
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            logger.debug("Refreshing repository \(repository.id, privacy: .public)")
            
            // Check repository status
            let status = try await repositoryService.checkRepository(repository)
            repository.status = status
            
            // Load snapshots if repository is ready
            if status == .ready {
                snapshots = try await repositoryService.listSnapshots(repository)
            }
            
            logger.info("Refresh successful: \(status) with \(snapshots.count) snapshots")
            
        } catch {
            logger.error("Refresh failed: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoading = false
    }
    
    func createSnapshot(paths: [URL], tags: [String]) async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            logger.debug("Creating snapshot with \(paths.count) paths and \(tags.count) tags")
            
            let snapshot = try await repositoryService.createSnapshot(
                repository,
                paths: paths,
                tags: tags
            )
            
            snapshots.append(snapshot)
            
            logger.info("Created snapshot \(snapshot.id)")
            
        } catch {
            logger.error("Failed to create snapshot: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoading = false
    }
    
    func deleteSnapshot(_ snapshot: ResticSnapshot) async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            logger.debug("Deleting snapshot \(snapshot.id)")
            
            try await repositoryService.deleteSnapshot(snapshot, from: repository)
            snapshots.removeAll { $0.id == snapshot.id }
            
            logger.info("Deleted snapshot \(snapshot.id)")
            
        } catch {
            logger.error("Failed to delete snapshot: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoading = false
    }
    
    func restoreSnapshot(_ snapshot: ResticSnapshot, to path: URL) async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            logger.debug("Restoring snapshot \(snapshot.id) to \(path.path)")
            
            try await repositoryService.restoreSnapshot(
                snapshot,
                to: path,
                from: repository
            )
            
            logger.info("Restored snapshot \(snapshot.id)")
            
        } catch {
            logger.error("Failed to restore snapshot: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoading = false
    }
}
