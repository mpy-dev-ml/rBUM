//
//  SnapshotListViewModel.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 7 February 2025
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

    enum Operation: String {
        case loading = "Loading snapshots"
        case restoring = "Restoring snapshot"
    }

    // MARK: - Published Properties

    @Published private(set) var repository: Repository
    @Published private(set) var snapshots: [ResticSnapshot] = []
    @Published private(set) var progress: Progress?
    @Published private(set) var isRestoringSnapshot = false
    @Published private(set) var currentOperation: Operation?
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
    private let restoreService: RestoreServiceProtocol
    private let logger: LoggerProtocol

    // MARK: - Initialization

    init(
        repository: Repository,
        repositoryService: RepositoryServiceProtocol,
        credentialsService: KeychainCredentialsManagerProtocol,
        securityService: SecurityServiceProtocol,
        bookmarkService: BookmarkServiceProtocol,
        restoreService: RestoreServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.repository = repository
        self.repositoryService = repositoryService
        self.credentialsService = credentialsService
        self.securityService = securityService
        self.bookmarkService = bookmarkService
        self.restoreService = restoreService
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Load snapshots for the repository
    func loadSnapshots() async {
        do {
            currentOperation = .loading
            snapshots = try await repositoryService.listSnapshots(for: repository)
            applyFilters()
        } catch {
            await handleError(error)
        } finally {
            currentOperation = nil
        }
    }

    /// Select a snapshot for restoration
    func selectSnapshot(_ snapshot: ResticSnapshot) {
        selectedSnapshot = snapshot
        showRestoreSheet = true
    }

    // MARK: - Private Methods

    private func applyFilters() {
        // Apply search filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            snapshots = snapshots.filter { snapshot in
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
            snapshots = snapshots.filter { Calendar.current.isDateInToday($0.time) }
        case .thisWeek:
            snapshots = snapshots.filter {
                Calendar.current.isDate(
                    $0.time,
                    equalTo: Date(),
                    toGranularity: .weekOfYear
                )
            }
        case .thisMonth:
            snapshots = snapshots.filter { Calendar.current.isDate($0.time, equalTo: Date(), toGranularity: .month) }
        case .thisYear:
            snapshots = snapshots.filter { Calendar.current.isDate($0.time, equalTo: Date(), toGranularity: .year) }
        case .tagged:
            snapshots = snapshots.filter { !($0.tags?.isEmpty ?? true) }
        }

        // Sort snapshots
        snapshots.sort { $0.time > $1.time }
    }

    private func handleError(_ error: Error) async {
        await MainActor.run {
            self.error = error
            self.showError = true
            self.logger.error("Error loading snapshots: \(error.localizedDescription)")
        }
    }
}
