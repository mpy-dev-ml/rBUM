//
//  RepositoryListViewModel.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 8 February 2025
//

import Core
import Foundation
import os.log
import SwiftUI

/// Manages the list of backup repositories
@MainActor
final class RepositoryListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var repositories: [Repository] = []
    @Published var error: Error?
    @Published var showError = false
    @Published private(set) var progress: Progress?
    @Published private(set) var state: State = .loading
    @Published private(set) var selectedRepository: Repository?

    // MARK: - Private Properties

    private let repositoryService: RepositoryServiceProtocol
    private let credentialsService: KeychainCredentialsManagerProtocol
    private let bookmarkService: BookmarkServiceProtocol
    private let securityService: SecurityServiceProtocol
    private let logger: Logger
    private let storage: RepositoryStorageProtocol

    // MARK: - Initialization

    init(
        repositoryService: RepositoryServiceProtocol,
        credentialsService: KeychainCredentialsManagerProtocol,
        bookmarkService: BookmarkServiceProtocol,
        securityService: SecurityServiceProtocol,
        storage: RepositoryStorageProtocol,
        logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "repository")
    ) {
        self.repositoryService = repositoryService
        self.credentialsService = credentialsService
        self.bookmarkService = bookmarkService
        self.securityService = securityService
        self.storage = storage
        self.logger = logger

        logger.debug("Initialized RepositoryListViewModel")
    }

    // MARK: - Public Methods

    /// Load all repositories
    func loadRepositories() async {
        logger.debug("Loading repositories")

        do {
            try await loadRepositoriesAsync()
        } catch {
            await MainActor.run {
                self.error = error
                self.showError = true
                self.progress?.cancel()
                self.logger.error("Failed to load repositories: \(error.localizedDescription)")
            }
        }
    }

    /// Delete a repository
    /// - Parameter repository: Repository to delete
    func deleteRepository(_ repository: Repository) async {
        logger.info("Deleting repository: \(repository.id)")

        do {
            // Create progress tracker
            let tracker = Progress(totalUnitCount: 1)
            progress = tracker

            // Delete repository
            try await handleRepositoryOperation(type: .delete, repository: repository)

            // Delete credentials
            try await credentialsService.delete(forId: repository.id.uuidString)

            // Update progress
            progress?.completedUnitCount = 1

            // Refresh list
            await loadRepositories()

            logger.info("Successfully deleted repository: \(repository.id)")
        } catch {
            progress?.cancel()
            self.error = error
            showError = true
            logger.error("Failed to delete repository: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func compareRepositoryNames(
        _ left: Repository,
        _ right: Repository
    ) -> Bool {
        let name1 = left.name
        let name2 = right.name
        let comparisonResult = name1.localizedCaseInsensitiveCompare(name2)
        return comparisonResult == .orderedAscending
    }

    private func loadRepositoriesAsync() async throws {
        try await handleRepositoryOperation(type: .load)
    }

    // Repository operation handling moved to RepositoryListViewModel+OperationHandling.swift

    /// Errors that can occur during repository UI operations
    enum RepositoryUIError: LocalizedError {
        case accessDenied(String)
        case securityRequirementsFailed(String)
        case refreshFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .accessDenied(let message):
                return "Access denied: \(message)"
            case .securityRequirementsFailed(let message):
                return "Security requirements failed: \(message)"
            case .refreshFailed(let message):
                return "Refresh failed: \(message)"
            }
        }
    }

    enum State {
        case loading
        // Add other states as needed
    }
}
