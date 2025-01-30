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
    @Published var error: Error?
    @Published var showError = false
    
    private let repositoryStorage: RepositoryStorageProtocol
    let repositoryCreationService: RepositoryCreationServiceProtocol
    private let resticService: ResticCommandServiceProtocol
    private let logger = Logging.logger(for: .repository)
    
    convenience init() {
        let credentialsManager = KeychainCredentialsManager()
        let processExecutor = ProcessExecutor()
        let resticService = ResticCommandService(
            credentialsManager: credentialsManager,
            processExecutor: processExecutor
        )
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
            repositories = try await repositoryStorage.list()
            logger.infoMessage("Loaded \(repositories.count) repositories")
        } catch {
            logger.errorMessage("Failed to load repositories: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
    
    func deleteRepository(_ repository: Repository) async {
        do {
            try await repositoryStorage.delete(forId: repository.id)
            if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
                repositories.remove(at: index)
            }
            logger.infoMessage("Deleted repository: \(repository.id)")
        } catch {
            logger.errorMessage("Failed to delete repository: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
}
