//
//  RepositoryDetailViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import SwiftUI
import Core

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
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    init(
        repository: Repository,
        repositoryService: RepositoryServiceProtocol = DefaultRepositoryService(),
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "RepositoryDetail")
    ) {
        self.repository = repository
        self.repositoryService = repositoryService
        self.logger = logger
        
        logger.debug("Viewing repository details", privacy: .public)
    }
    
    // MARK: - Repository Operations
    
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            logger.debug("Refreshing repository", metadata: [
                "id": .string(repository.id)
            ])
            
            // Check repository status
            let status = try await repositoryService.checkRepository(repository, credentials: repository.credentials)
            repository.status = status
            
            // Load snapshots if repository is ready
            if status == .ready {
                snapshots = try await repositoryService.listSnapshots(in: repository, credentials: repository.credentials)
            }
            
            logger.info("Refresh successful", metadata: [
                "id": .string(repository.id),
                "status": .string("\(status)"),
                "snapshots": .string("\(snapshots.count)")
            ])
            
        } catch {
            logger.error("Refresh failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            self.error = error
        }
        
        isLoading = false
    }
    
    func createSnapshot(paths: [URL], tags: [String]) async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            logger.debug("Creating snapshot", metadata: [
                "id": .string(repository.id),
                "paths": .string("\(paths.count) paths"),
                "tags": .string("\(tags.count) tags")
            ])
            
            let snapshot = try await repositoryService.createSnapshot(
                in: repository,
                credentials: repository.credentials,
                paths: paths,
                tags: tags
            )
            
            snapshots.append(snapshot)
            
            logger.info("Snapshot created", metadata: [
                "id": .string(repository.id),
                "snapshot": .string(snapshot.id)
            ])
            
        } catch {
            logger.error("Failed to create snapshot", metadata: [
                "error": .string(error.localizedDescription)
            ])
            self.error = error
        }
        
        isLoading = false
    }
    
    func deleteSnapshot(_ snapshot: ResticSnapshot) async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            logger.debug("Deleting snapshot", metadata: [
                "id": .string(repository.id),
                "snapshot": .string(snapshot.id)
            ])
            
            try await repositoryService.deleteSnapshot(snapshot, from: repository, credentials: repository.credentials)
            snapshots.removeAll { $0.id == snapshot.id }
            
            logger.info("Snapshot deleted", metadata: [
                "id": .string(repository.id),
                "snapshot": .string(snapshot.id)
            ])
            
        } catch {
            logger.error("Failed to delete snapshot", metadata: [
                "error": .string(error.localizedDescription)
            ])
            self.error = error
        }
        
        isLoading = false
    }
    
    func restoreSnapshot(_ snapshot: ResticSnapshot, to path: URL) async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            logger.debug("Restoring snapshot", metadata: [
                "id": .string(repository.id),
                "snapshot": .string(snapshot.id),
                "path": .string(path.path)
            ])
            
            try await repositoryService.restoreSnapshot(snapshot, from: repository, credentials: repository.credentials, to: path)
            
            logger.info("Snapshot restored", metadata: [
                "id": .string(repository.id),
                "snapshot": .string(snapshot.id)
            ])
            
        } catch {
            logger.error("Failed to restore snapshot", metadata: [
                "error": .string(error.localizedDescription)
            ])
            self.error = error
        }
        
        isLoading = false
    }
}
