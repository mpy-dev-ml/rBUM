//
//  RepositoryListViewModel.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
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
    
    // MARK: - Private Properties
    
    private let repositoryService: RepositoryServiceProtocol
    private let credentialsService: KeychainCredentialsManagerProtocol
    private let bookmarkService: BookmarkServiceProtocol
    private let securityService: SecurityServiceProtocol
    private let logger: Logger
    
    // MARK: - Initialization
    
    init(
        repositoryService: RepositoryServiceProtocol,
        credentialsService: KeychainCredentialsManagerProtocol,
        bookmarkService: BookmarkServiceProtocol,
        securityService: SecurityServiceProtocol,
        logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "repository")
    ) {
        self.repositoryService = repositoryService
        self.credentialsService = credentialsService
        self.bookmarkService = bookmarkService
        self.securityService = securityService
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
        let repositories = try await repositoryService
            .listRepositories()
            .sorted(by: compareRepositoryNames)
        
        // Create progress tracker
        let tracker = Progress(totalUnitCount: Int64(repositories.count))
        self.progress = tracker
        
        // Verify each repository
        let validRepos = await withTaskGroup(of: (Repository?, Error?).self) { group in
            for repository in repositories {
                group.addTask {
                    do {
                        // Validate repository access
                        try await self.securityService.validateAccess(to: URL(fileURLWithPath: repository.path))
                        
                        // Check repository status
                        try await self.repositoryService.updateRepository(repository)
                        
                        // Update progress
                        await MainActor.run {
                            tracker.completedUnitCount += 1
                        }
                        
                        return (repository, nil)
                    } catch {
                        let message = "Repository validation failed: \(error.localizedDescription)"
                        self.logger.error("\(message)")
                        return (nil, error)
                    }
                }
            }
            
            var repos: [Repository] = []
            var errors: [Error] = []
            
            for await (repo, error) in group {
                if let repo = repo {
                    repos.append(repo)
                }
                if let error = error {
                    errors.append(error)
                }
            }
            
            // Log any errors
            if !errors.isEmpty {
                self.logger.warning("\(errors.count) repositories failed validation")
            }
            
            return repos
        }
        
        await MainActor.run {
            self.repositories = validRepos
            self.progress?.completedUnitCount = Int64(validRepos.count)
            self.logger.info("Loaded \(validRepos.count) valid repositories")
        }
    }
    
    /// Delete a repository
    /// - Parameter repository: Repository to delete
    func deleteRepository(_ repository: Repository) async {
        logger.info("Deleting repository: \(repository.id)")
        
        do {
            // Create progress tracker
            let tracker = Progress(totalUnitCount: 1)
            self.progress = tracker
            
            // Delete repository
            try await repositoryService.deleteRepository(repository)
            
            // Delete credentials
            try await credentialsService.delete(forId: repository.id.uuidString)
            
            // Delete bookmark
            try await bookmarkService.stopAccessing(URL(fileURLWithPath: repository.path))
            
            // Update progress
            progress?.completedUnitCount = 1
            
            // Refresh list
            await loadRepositories()
            
            logger.info("Successfully deleted repository: \(repository.id)")
        } catch {
            progress?.cancel()
            self.error = error
            self.showError = true
            logger.error("Failed to delete repository: \(error.localizedDescription)")
        }
    }
}

/// Errors that can occur during repository UI operations
enum RepositoryUIError: LocalizedError {
    case accessDenied(String)
    case bookmarkInvalid(String)
    case repositoryNotFound(String)
    case operationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied(let message):
            return "Access denied: \(message)"
        case .bookmarkInvalid(let message):
            return "Invalid bookmark: \(message)"
        case .repositoryNotFound(let message):
            return "Repository not found: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
}
