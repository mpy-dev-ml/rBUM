//
//  RepositoryListViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import SwiftUI

/// Manages the list of backup repositories
@MainActor
final class RepositoryListViewModel: ObservableObject {
    @Published private(set) var repositories: [Repository] = []
    @Published var error: Error?
    @Published var showError = false
    
    private let repositoryStorage: RepositoryStorageProtocol
    let repositoryCreationService: RepositoryCreationServiceProtocol
    private let resticService: ResticCommandServiceProtocol
    private let logger = Logging.logger(for: .repository)
    
    convenience init() {
        let resticService = ResticCommandService()  // Use default parameters
        let repositoryStorage = RepositoryStorage()
        let repositoryCreationService = RepositoryCreationService(
            resticService: resticService,
            repositoryStorage: repositoryStorage
        )
        
        self.init(
            resticService: resticService,
            repositoryStorage: repositoryStorage,
            repositoryCreationService: repositoryCreationService
        )
    }
    
    init(
        resticService: ResticCommandServiceProtocol,
        repositoryStorage: RepositoryStorageProtocol,
        repositoryCreationService: RepositoryCreationServiceProtocol
    ) {
        self.resticService = resticService
        self.repositoryStorage = repositoryStorage
        self.repositoryCreationService = repositoryCreationService
    }
    
    func loadRepositories() async {
        do {
            var storedRepos = try repositoryStorage.list()
            
            // Verify each repository still exists
            storedRepos = storedRepos.filter { repository in
                let exists = FileManager.default.fileExists(atPath: repository.path)
                if !exists {
                    logger.warning("Repository at \(repository.path) no longer exists, removing from storage")
                    try? repositoryStorage.delete(repository)
                }
                return exists
            }
            
            repositories = storedRepos
            logger.infoMessage("Loaded \(repositories.count) valid repositories")
        } catch {
            logger.error("Failed to load repositories: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
    
    func deleteRepository(_ repository: Repository) async {
        do {
            try repositoryStorage.delete(repository)
            await loadRepositories()  // Refresh list after deletion
            logger.infoMessage("Deleted repository: \(repository.id)")
        } catch {
            logger.error("Failed to delete repository: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
}
