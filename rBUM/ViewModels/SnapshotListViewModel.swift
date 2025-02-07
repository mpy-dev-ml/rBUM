//
//  SnapshotListViewModel.swift
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

import Core
import Foundation
import os.log
import SwiftUI

/// Manages the list of snapshots for a repository
@MainActor
final class SnapshotListViewModel: ObservableObject {
    // MARK: - Types

    enum Filter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
        case tagged = "Tagged"
    }

    // MARK: - Published Properties

    @Published private(set) var repository: Repository
    @Published private(set) var snapshots: [ResticSnapshot] = []
    @Published private(set) var progress: Progress?
    @Published var error: Error?
    @Published var showError = false
    @Published var selectedSnapshot: ResticSnapshot?
    @Published var showRestoreSheet = false
    @Published var restorePath: URL?
    @Published var searchText = ""
    @Published var selectedFilter: Filter = .all

    // MARK: - Private Properties

    private let repositoryService: RepositoryServiceProtocol
    private let credentialsService: KeychainCredentialsManagerProtocol
    private let securityService: SecurityServiceProtocol
    private let bookmarkService: BookmarkServiceProtocol
    private let logger: Logger
    private let calendar = Calendar.current

    // MARK: - Initialization

    init(
        repository: Repository,
        repositoryService: RepositoryServiceProtocol,
        credentialsService: KeychainCredentialsManagerProtocol,
        securityService: SecurityServiceProtocol,
        bookmarkService: BookmarkServiceProtocol,
        logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "snapshots")
    ) {
        self.repository = repository
        self.repositoryService = repositoryService
        self.credentialsService = credentialsService
        self.securityService = securityService
        self.bookmarkService = bookmarkService
        self.logger = logger

        logger.debug(
            "Initialized SnapshotListViewModel for repository: \(repository.id)",
            file: #file,
            function: #function,
            line: #line
        )
    }

    // MARK: - Public Methods

    /// Load snapshots from the repository
    func loadSnapshots() async {
        logger.debug(
            "Loading snapshots for repository: \(repository.id)",
            file: #file,
            function: #function,
            line: #line
        )

        do {
            try await handleSnapshotOperation()
        } catch {
            progress?.cancel()
            self.error = error
            showError = true
            logger.error(
                "Failed to load snapshots: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    /// Delete a snapshot
    /// - Parameter snapshot: The snapshot to delete
    func deleteSnapshot(_ snapshot: ResticSnapshot) async {
        logger.debug("Deleting snapshot: \(snapshot.id)", file: #file, function: #function, line: #line)

        do {
            try await handleSnapshotDeletion(snapshot)
        } catch {
            progress?.cancel()
            self.error = error
            showError = true
            logger.error(
                "Failed to delete snapshot: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    /// Restore a snapshot
    /// - Parameters:
    ///   - snapshot: The snapshot to restore
    ///   - path: The path to restore to
    func restoreSnapshot(_ snapshot: ResticSnapshot, to path: URL) async {
        logger.debug("Restoring snapshot \(snapshot.id) to \(path.path)", file: #file, function: #function, line: #line)

        do {
            try await handleSnapshotRestoration(snapshot, to: path)
        } catch {
            progress?.cancel()
            self.error = error
            showError = true
            logger.error(
                "Failed to restore snapshot: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    // MARK: - Private Methods

    private func handleSnapshotOperation() async throws {
        try await validateSnapshotPrerequisites()
        try await loadSnapshotsFromRepository()
        try await processSnapshots()
    }

    private func validateSnapshotPrerequisites() async throws {
        guard let repository = repository else {
            throw SnapshotError.missingRepository
        }

        // Validate repository access
        try await validateRepositoryAccess(repository)

        // Validate repository health
        try await validateRepositoryHealth(repository)
    }

    private func validateRepositoryAccess(_ repository: Repository) async throws {
        guard let url = repository.url else {
            throw SnapshotError.invalidRepository("Repository URL is missing")
        }

        guard try await securityService.validateAccess(to: url) else {
            throw SnapshotError.accessDenied("Cannot access repository")
        }

        guard try await securityService.validateReadAccess(to: url) else {
            throw SnapshotError.accessDenied("Cannot read from repository")
        }
    }

    private func validateRepositoryHealth(_ repository: Repository) async throws {
        let health = try await healthCheckService.checkHealth(of: repository)
        guard health.status == .healthy else {
            throw SnapshotError.unhealthyRepository(
                "Repository is not healthy: \(health.message ?? "Unknown error")"
            )
        }
    }

    private func loadSnapshotsFromRepository() async throws {
        guard let repository = repository else { return }

        isLoading = true
        currentOperation = .loading

        do {
            let credentials = try await credentialsService.getCredentials(for: repository)
            snapshots = try await repositoryService.listSnapshots(repository, credentials: credentials)
        } catch {
            handleSnapshotError(error)
            throw error
        }
    }

    private func processSnapshots() async throws {
        guard !snapshots.isEmpty else {
            snapshots = []
            return
        }

        // Apply filters
        var filtered = snapshots

        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { snapshot in
                let nameMatch = snapshot.hostname.lowercased().contains(searchLower)
                let pathMatch = snapshot.paths.contains { $0.lowercased().contains(searchLower) }
                let tagMatch = snapshot.tags?.contains { $0.lowercased().contains(searchLower) } ?? false

                return nameMatch || pathMatch || tagMatch
            }
        }

        // Apply time filter
        switch selectedFilter {
        case .all:
            break
        case .today:
            filtered = filtered.filter { calendar.isDateInToday($0.time) }
        case .thisWeek:
            filtered = filtered.filter { calendar.isDate($0.time, equalTo: Date(), toGranularity: .weekOfYear) }
        case .thisMonth:
            filtered = filtered.filter { calendar.isDate($0.time, equalTo: Date(), toGranularity: .month) }
        case .thisYear:
            filtered = filtered.filter { calendar.isDate($0.time, equalTo: Date(), toGranularity: .year) }
        case .tagged:
            filtered = filtered.filter { !($0.tags?.isEmpty ?? true) }
        }

        // Sort snapshots
        filtered.sort { $0.time > $1.time }

        snapshots = filtered
    }

    private func handleSnapshotDeletion(_ snapshot: ResticSnapshot) async throws {
        guard let repository = repository else { return }

        isDeletingSnapshot = true
        currentOperation = .deleting

        do {
            // Get credentials
            let credentials = try await credentialsService.getCredentials(for: repository)

            // Delete snapshot
            try await repositoryService.deleteSnapshot(snapshot, from: repository, credentials: credentials)

            // Remove from lists
            snapshots.removeAll { $0.id == snapshot.id }

            // Log success
            logger.info("Snapshot deleted successfully", metadata: [
                "snapshot": .string(snapshot.id),
                "repository": .string(repository.id.uuidString)
            ])

            // Show success notification
            notificationCenter.post(
                name: .snapshotDeleted,
                object: nil,
                userInfo: [
                    "snapshot": snapshot,
                    "repository": repository
                ]
            )

        } catch {
            handleSnapshotError(error)
            throw error
        }

        isDeletingSnapshot = false
        currentOperation = .idle
    }

    private func handleSnapshotRestoration(_ snapshot: ResticSnapshot, to destination: URL) async throws {
        guard let repository = repository else { return }

        isRestoringSnapshot = true
        currentOperation = .restoring

        do {
            // Validate destination
            try await validateRestoreDestination(destination)

            // Get credentials
            let credentials = try await credentialsService.getCredentials(for: repository)

            // Restore snapshot
            try await repositoryService.restoreSnapshot(
                snapshot,
                from: repository,
                to: destination,
                credentials: credentials
            )

            // Log success
            logger.info("Snapshot restored successfully", metadata: [
                "snapshot": .string(snapshot.id),
                "repository": .string(repository.id.uuidString),
                "destination": .string(destination.path)
            ])

            // Show success notification
            notificationCenter.post(
                name: .snapshotRestored,
                object: nil,
                userInfo: [
                    "snapshot": snapshot,
                    "repository": repository,
                    "destination": destination
                ]
            )

        } catch {
            handleSnapshotError(error)
            throw error
        }

        isRestoringSnapshot = false
        currentOperation = .idle
    }

    private func validateRestoreDestination(_ destination: URL) async throws {
        // Check destination access
        guard try await securityService.validateAccess(to: destination) else {
            throw SnapshotError.accessDenied("Cannot access restore destination")
        }

        // Check write permissions
        guard try await securityService.validateWriteAccess(to: destination) else {
            throw SnapshotError.accessDenied("Cannot write to restore destination")
        }
    }

    private func handleSnapshotError(_ error: Error) {
        Task { @MainActor in
            isLoading = false
            currentOperation = .failed
            lastError = error

            // Log error
            logger.error("Snapshot operation failed", metadata: [
                "error": .string(error.localizedDescription),
                "repository": .string(repository.id.uuidString)
            ])

            // Show error notification
            notificationCenter.post(
                name: .snapshotOperationFailed,
                object: nil,
                userInfo: [
                    "error": error,
                    "repository": repository as Any
                ]
            )
        }
    }

    // MARK: - Computed Properties

    /// Filtered snapshots based on search text and selected filter
    var filteredSnapshots: [ResticSnapshot] {
        snapshots.filter { snapshot in
            // Apply search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let nameMatch = snapshot.hostname.lowercased().contains(searchLower)
                let pathMatch = snapshot.paths.contains { $0.lowercased().contains(searchLower) }
                let tagMatch = snapshot.tags?.contains { $0.lowercased().contains(searchLower) } ?? false

                guard nameMatch || pathMatch || tagMatch else {
                    return false
                }
            }

            // Apply time filter
            switch selectedFilter {
            case .all:
                return true
            case .today:
                return calendar.isDateInToday(snapshot.time)
            case .thisWeek:
                return calendar.isDate(snapshot.time, equalTo: Date(), toGranularity: .weekOfYear)
            case .thisMonth:
                return calendar.isDate(snapshot.time, equalTo: Date(), toGranularity: .month)
            case .thisYear:
                return calendar.isDate(snapshot.time, equalTo: Date(), toGranularity: .year)
            case .tagged:
                return !(snapshot.tags?.isEmpty ?? true)
            }
        }
    }

    var groupedSnapshots: [(String, [ResticSnapshot])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSnapshots) { snapshot in
            calendar.startOfDay(for: snapshot.time)
        }

        return grouped.map { date, snapshots in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return (formatter.string(from: date), snapshots)
        }.sorted { $0.0 > $1.0 }
    }

    var uniqueTags: [String] {
        Array(Set(snapshots.flatMap(\.tags))).sorted()
    }
}

// Add sandbox-specific error types
extension RepositoryError {
    static func sandboxViolation(_ message: String) -> RepositoryError {
        .operationFailed("Sandbox violation: \(message)")
    }

    static func bookmarkError(_ message: String) -> RepositoryError {
        .operationFailed("Bookmark error: \(message)")
    }
}
