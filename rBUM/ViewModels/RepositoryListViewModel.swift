//
//  RepositoryListViewModel.swift
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

/// Manages the list of backup repositories
@MainActor
final class RepositoryListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var repositories: [Repository] = []
    @Published var error: Error?
    @Published var showError = false
    @Published private(set) var progress: ProgressTracker?
    
    // MARK: - Private Properties
    
    private let repositoryService: Core.RepositoryServiceProtocol
    private let credentialsService: CredentialsServiceProtocol
    private let bookmarkService: BookmarkServiceProtocol
    private let securityService: SecurityServiceProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    convenience init() {
        self.init(
            repositoryService: Core.RepositoryService(),
            credentialsService: CredentialsService(),
            bookmarkService: BookmarkService(),
            securityService: SecurityService(),
            logger: Logging.logger(for: .repository)
        )
    }
    
    init(
        repositoryService: Core.RepositoryServiceProtocol,
        credentialsService: CredentialsServiceProtocol,
        bookmarkService: BookmarkServiceProtocol,
        securityService: SecurityServiceProtocol,
        logger: LoggerProtocol = Logging.logger(for: .repository)
    ) {
        self.repositoryService = repositoryService
        self.credentialsService = credentialsService
        self.bookmarkService = bookmarkService
        self.securityService = securityService
        self.logger = logger
        
        logger.debug("Initialized RepositoryListViewModel", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    // MARK: - Public Methods
    
    /// Load all repositories
    func loadRepositories() async {
        logger.debug("Loading repositories", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            let status = try await repositoryService.listRepositories()
            
            // Create progress tracker
            let tracker = ProgressTracker(total: Int64(status.count))
            self.progress = tracker
            
            // Verify each repository
            let validRepos = await withTaskGroup(of: (Repository?, Error?).self) { group in
                for repository in status {
                    group.addTask {
                        do {
                            // Validate repository access
                            try self.securityService.validateAccess(to: repository.url)
                            
                            // Check repository status
                            let repoStatus = try await self.repositoryService.checkRepository(repository)
                            
                            // Update progress
                            await MainActor.run {
                                self.progress?.update(processed: 1)
                            }
                            
                            return (repository, nil)
                        } catch {
                            self.logger.error("Repository validation failed: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
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
                    self.logger.warning("\(errors.count) repositories failed validation", privacy: .public, file: #file, function: #function, line: #line)
                }
                
                return repos
            }
            
            await MainActor.run {
                self.repositories = validRepos
                self.progress?.complete()
                self.logger.info("Loaded \(validRepos.count) valid repositories", privacy: .public, file: #file, function: #function, line: #line)
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.showError = true
                self.progress?.fail(error)
                self.logger.error("Failed to load repositories: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            }
        }
    }
    
    /// Delete a repository
    /// - Parameter repository: Repository to delete
    func deleteRepository(_ repository: Repository) async {
        logger.info("Deleting repository: \(repository.id)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Create progress tracker
            let tracker = ProgressTracker(total: 1)
            self.progress = tracker
            
            // Delete repository
            try await repositoryService.deleteRepository(repository)
            
            // Delete credentials
            try await credentialsService.deleteCredentials(for: repository)
            
            // Delete bookmark
            try bookmarkService.deleteBookmark(for: repository.url)
            
            // Update progress
            progress?.complete()
            
            // Refresh list
            await loadRepositories()
            
            logger.info("Successfully deleted repository: \(repository.id)", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            progress?.fail(error)
            self.error = error
            self.showError = true
            logger.error("Failed to delete repository: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
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
