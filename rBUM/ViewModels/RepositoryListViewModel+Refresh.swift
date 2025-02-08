//
//  RepositoryListViewModel+Refresh.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Core
import Foundation

extension RepositoryListViewModel {
    /// Refreshes repository details
    func refreshRepositoryDetails(for repositories: [Repository]) async throws {
        for repository in repositories {
            do {
                // Refresh repository status
                let status = try await refreshRepositoryStatus(repository)
                
                // Update repository with new status
                if let index = self.repositories.firstIndex(where: { $0.id == repository.id }) {
                    self.repositories[index].status = status
                }
            } catch {
                logger.error("Failed to refresh repository status: \(error.localizedDescription)")
                throw RepositoryUIError.refreshFailed("Failed to refresh repository status")
            }
        }
    }
    
    /// Refreshes status for a single repository
    private func refreshRepositoryStatus(_ repository: Repository) async throws -> RepositoryStatus {
        // Validate repository access
        guard try await validateRepositoryAccess(repository) else {
            return .inaccessible
        }
        
        // Check repository health
        return try await checkRepositoryHealth(repository)
    }
    
    /// Validates access to a repository
    private func validateRepositoryAccess(_ repository: Repository) async throws -> Bool {
        return try await securityService.validateRepositoryAccess(repository.url)
    }
    
    /// Checks repository health
    private func checkRepositoryHealth(_ repository: Repository) async throws -> RepositoryStatus {
        let health = try await repositoryService.checkRepositoryHealth(repository)
        return health.isHealthy ? .healthy : .unhealthy(health.failureReason ?? "Unknown error")
    }
}
