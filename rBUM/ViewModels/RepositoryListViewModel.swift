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
        try await handleRepositoryOperation(type: .load)
    }

    private enum RepositoryOperationType {
        case load
        case refresh
        case delete
    }

    private func handleRepositoryOperation(
        type: RepositoryOperationType,
        repository: Repository? = nil
    ) async throws {
        let operationId = UUID()
        
        do {
            // Start operation
            try await startRepositoryOperation(operationId, type: type, repository: repository)
            
            // Validate prerequisites
            try await validateRepositoryPrerequisites(type: type, repository: repository)
            
            // Execute operation
            try await executeRepositoryOperation(type: type, repository: repository)
            
            // Complete operation
            try await completeRepositoryOperation(operationId, success: true)
            
        } catch {
            // Handle failure
            try await completeRepositoryOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    private func startRepositoryOperation(
        _ id: UUID,
        type: RepositoryOperationType,
        repository: Repository?
    ) async throws {
        // Record operation start
        let operation = RepositoryOperation(
            id: id,
            type: type,
            repository: repository,
            timestamp: Date(),
            status: .inProgress
        )
        // operationRecorder.recordOperation(operation)
        
        // Log operation start
        logger.info("Starting repository operation", metadata: [
            "operation": .string(id.uuidString),
            "type": .string(type.rawValue),
            "repository": repository.map { .string($0.id.uuidString) } ?? .string("none")
        ])
    }
    
    private func validateRepositoryPrerequisites(
        type: RepositoryOperationType,
        repository: Repository?
    ) async throws {
        switch type {
        case .load:
            try await validateLoadPrerequisites()
        case .refresh:
            try await validateRefreshPrerequisites()
        case .delete:
            try await validateDeletePrerequisites(repository)
        }
    }
    
    private func validateLoadPrerequisites() async throws {
        // Check storage access
        guard try await hasStorageAccess() else {
            throw RepositoryUIError.accessDenied("Cannot access repository storage")
        }
    }
    
    private func validateRefreshPrerequisites() async throws {
        // Check storage access
        guard try await hasStorageAccess() else {
            throw RepositoryUIError.accessDenied("Cannot access repository storage")
        }
        
        // Check network access
        guard try await hasNetworkAccess() else {
            throw RepositoryUIError.networkError("Cannot access network")
        }
    }
    
    private func validateDeletePrerequisites(_ repository: Repository?) async throws {
        // Check repository exists
        guard let repository = repository else {
            throw RepositoryUIError.invalidRepository("No repository specified")
        }
        
        // Check repository access
        guard try await hasRepositoryAccess(repository) else {
            throw RepositoryUIError.accessDenied("Cannot access repository")
        }
        
        // Check repository is not in use
        guard try await !isRepositoryInUse(repository) else {
            throw RepositoryUIError.repositoryInUse("Repository is currently in use")
        }
    }
    
    private func hasStorageAccess() async throws -> Bool {
        // Check storage permissions
        return try await securityService.validateAccess(
            to: FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
        )
    }
    
    private func hasNetworkAccess() async throws -> Bool {
        // Check network reachability
        return true // Replace with actual implementation
    }
    
    private func hasRepositoryAccess(_ repository: Repository) async throws -> Bool {
        guard let url = repository.url else { return false }
        
        // Check repository permissions
        return try await securityService.validateAccess(to: url)
    }
    
    private func isRepositoryInUse(_ repository: Repository) async throws -> Bool {
        // Check active operations
        return false // Replace with actual implementation
    }
    
    private func executeRepositoryOperation(
        type: RepositoryOperationType,
        repository: Repository?
    ) async throws {
        switch type {
        case .load:
            try await executeLoadOperation()
        case .refresh:
            try await executeRefreshOperation()
        case .delete:
            if let repository = repository {
                try await executeDeleteOperation(repository)
            }
        }
    }
    
    private func executeLoadOperation() async throws {
        // Load repositories from storage
        let repositories = try await repositoryService.listRepositories()
        
        // Update repositories
        await updateRepositories(repositories)
        
        // Load repository details
        try await loadRepositoryDetails(for: repositories)
    }
    
    private func executeRefreshOperation() async throws {
        // Refresh repository list
        let repositories = try await repositoryService.listRepositories()
        
        // Update repositories
        await updateRepositories(repositories)
        
        // Refresh repository details
        try await refreshRepositoryDetails(for: repositories)
    }
    
    private func executeDeleteOperation(_ repository: Repository) async throws {
        // Delete repository files
        try await deleteRepositoryFiles(repository)
        
        // Delete repository from storage
        try await deleteRepositoryFromStorage(repository)
        
        // Remove repository from list
        await removeRepository(repository)
    }
    
    private func updateRepositories(_ repositories: [Repository]) async {
        await MainActor.run {
            self.repositories = repositories.sorted(by: self.compareRepositoryNames)
            self.progress?.completedUnitCount = Int64(repositories.count)
            self.logger.info("Loaded \(repositories.count) valid repositories")
        }
    }
    
    private func loadRepositoryDetails(for repositories: [Repository]) async throws {
        for repository in repositories {
            do {
                // Load repository status
                let status = try await loadRepositoryStatus(repository)
                
                // Update repository status
                await updateRepositoryStatus(repository, status: status)
                
            } catch {
                logger.error("Failed to load repository details", metadata: [
                    "repository": .string(repository.id.uuidString),
                    "error": .string(error.localizedDescription)
                ])
            }
        }
    }
    
    private func refreshRepositoryDetails(for repositories: [Repository]) async throws {
        for repository in repositories {
            do {
                // Refresh repository status
                let status = try await refreshRepositoryStatus(repository)
                
                // Update repository status
                await updateRepositoryStatus(repository, status: status)
                
            } catch {
                logger.error("Failed to refresh repository details", metadata: [
                    "repository": .string(repository.id.uuidString),
                    "error": .string(error.localizedDescription)
                ])
            }
        }
    }
    
    private func loadRepositoryStatus(_ repository: Repository) async throws -> RepositoryStatus {
        // Get repository stats
        let stats = try await repositoryService.getStats(for: repository)
        
        // Create status
        return RepositoryStatus(
            totalSize: stats.totalSize,
            totalFiles: stats.totalFiles,
            lastBackup: stats.lastBackup,
            health: .healthy
        )
    }
    
    private func refreshRepositoryStatus(_ repository: Repository) async throws -> RepositoryStatus {
        // Check repository health
        let health = try await checkRepositoryHealth(repository)
        
        // Get repository stats
        let stats = try await repositoryService.getStats(for: repository)
        
        // Create status
        return RepositoryStatus(
            totalSize: stats.totalSize,
            totalFiles: stats.totalFiles,
            lastBackup: stats.lastBackup,
            health: health
        )
    }
    
    private func checkRepositoryHealth(_ repository: Repository) async throws -> RepositoryHealth {
        // Check repository integrity
        let result = try await repositoryService.check(repository)
        
        if result.errors.isEmpty {
            return .healthy
        } else {
            return .unhealthy(result.errors)
        }
    }
    
    private func updateRepositoryStatus(
        _ repository: Repository,
        status: RepositoryStatus
    ) async {
        await MainActor.run {
            // Update repository status
        }
    }
    
    private func deleteRepositoryFiles(_ repository: Repository) async throws {
        guard let url = repository.url else { return }
        
        // Delete repository directory
        try FileManager.default.removeItem(at: url)
        
        // Delete repository bookmarks
        try await deleteRepositoryBookmarks(repository)
    }
    
    private func deleteRepositoryBookmarks(_ repository: Repository) async throws {
        guard let url = repository.url else { return }
        
        // Delete security bookmark
        try await bookmarkService.stopAccessing(url)
    }
    
    private func deleteRepositoryFromStorage(_ repository: Repository) async throws {
        // Delete from storage
        try await repositoryService.deleteRepository(repository)
    }
    
    private func removeRepository(_ repository: Repository) async {
        await MainActor.run {
            self.repositories.removeAll { $0.id == repository.id }
            self.logger.info("Removed repository: \(repository.id)")
        }
    }
    
    private func completeRepositoryOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async throws {
        // Update operation status
        // operationRecorder.updateOperation(id, status: status, error: error)
        
        // Log completion
        logger.info("Completed repository operation", metadata: [
            "operation": .string(id.uuidString),
            "status": .string(success ? "completed" : "failed"),
            "error": error.map { .string($0.localizedDescription) } ?? .string("none")
        ])
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
}

/// Errors that can occur during repository UI operations
enum RepositoryUIError: LocalizedError {
    case accessDenied(String)
    case bookmarkInvalid(String)
    case repositoryNotFound(String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .accessDenied(message):
            "Access denied: \(message)"
        case let .bookmarkInvalid(message):
            "Invalid bookmark: \(message)"
        case let .repositoryNotFound(message):
            "Repository not found: \(message)"
        case let .operationFailed(message):
            "Operation failed: \(message)"
        }
    }
}
