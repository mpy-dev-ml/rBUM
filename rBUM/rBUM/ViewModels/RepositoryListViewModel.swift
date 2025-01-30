//
//  RepositoryListViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import SwiftUI

@MainActor
final class RepositoryListViewModel: ObservableObject {
    @Published private(set) var repositories: [Repository] = []
    @Published var showCreationSheet = false
    @Published var error: Error?
    @Published var showError = false
    
    private let repositoryStorage: RepositoryStorageProtocol
    private let logger = Logging.logger(for: .repository)
    
    init(repositoryStorage: RepositoryStorageProtocol) {
        self.repositoryStorage = repositoryStorage
    }
    
    func loadRepositories() {
        do {
            repositories = try repositoryStorage.list()
            logger.infoMessage("Loaded \(repositories.count) repositories")
        } catch {
            logger.errorMessage("Failed to load repositories: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
    
    func showCreateRepository() {
        showCreationSheet = true
    }
    
    func handleNewRepository(_ repository: Repository) {
        // Only add if not already in list
        if !repositories.contains(where: { $0.id == repository.id }) {
            repositories.append(repository)
            repositories.sort { $0.name < $1.name }
        }
    }
    
    func deleteRepository(_ repository: Repository) {
        do {
            try repositoryStorage.delete(forId: repository.id)
            repositories.removeAll { $0.id == repository.id }
            logger.infoMessage("Deleted repository: \(repository.id)")
        } catch {
            logger.errorMessage("Failed to delete repository: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
}
