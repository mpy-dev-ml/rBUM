//
//  SnapshotListViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import SwiftUI

@MainActor
final class SnapshotListViewModel: ObservableObject {
    enum Filter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
        case tagged = "Tagged"
    }
    
    struct PruneOptions {
        var keepLast: Int?
        var keepDaily: Int?
        var keepWeekly: Int?
        var keepMonthly: Int?
        var keepYearly: Int?
        var tags: [String]?
    }
    
    @Published private(set) var repository: Repository
    @Published private(set) var snapshots: [Snapshot] = []
    @Published private(set) var isLoading: Bool = false
    @Published var error: Error?
    @Published var showError: Bool = false
    @Published var selectedSnapshot: Snapshot?
    @Published var showRestoreSheet = false
    @Published var restorePath: URL?
    @Published var searchText: String = ""
    @Published var selectedFilter: Filter = .all
    @Published var showPruneSheet = false
    @Published var pruneOptions = PruneOptions()
    
    private let resticService: ResticCommandServiceProtocol
    private let credentialsManager: KeychainCredentialsManagerProtocol
    private let logger = Logging.logger(for: .snapshots)
    private let calendar = Calendar.current
    
    init(
        repository: Repository,
        resticService: ResticCommandServiceProtocol = ResticCommandService(
            fileManager: .default,
            logger: Logging.logger(for: .snapshots)
        ),
        credentialsManager: KeychainCredentialsManagerProtocol = KeychainCredentialsManager(
            keychainService: KeychainService()
        )
    ) {
        self.repository = repository
        self.resticService = resticService
        self.credentialsManager = credentialsManager
    }
    
    @MainActor
    func loadSnapshots() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get repository credentials
            let credentials = try await credentialsManager.retrieve(forId: repository.id)
            
            // Create Repository with credentials
            let repoWithCredentials = Repository(
                id: repository.id,
                name: repository.name,
                path: repository.path,
                createdAt: repository.createdAt,
                credentials: credentials
            )
            
            // List snapshots
            let resticSnapshots = try await resticService.listSnapshots(in: repoWithCredentials)
            
            // Convert ResticSnapshot to Snapshot
            snapshots = resticSnapshots.map { resticSnapshot in
                Snapshot(
                    id: resticSnapshot.id,
                    time: resticSnapshot.time,
                    hostname: resticSnapshot.hostname,
                    username: ProcessInfo.processInfo.userName,
                    paths: resticSnapshot.paths,
                    tags: resticSnapshot.tags ?? [],
                    sizeInBytes: 0  // Size will be fetched separately if needed
                )
            }
            
            snapshots.sort { $0.time > $1.time } // Sort by newest first
            logger.infoMessage("Loaded \(snapshots.count) snapshots")
        } catch {
            logger.errorMessage("Failed to load snapshots: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
    
    // Note: Snapshot deletion is not currently supported by ResticCommandService
    // This functionality will need to be added when required
    func deleteSnapshot(_ snapshot: Snapshot) async {
        self.error = ResticError.commandError("Snapshot deletion is not currently supported")
        showError = true
    }
    
    // Note: Snapshot restoration is not currently supported by ResticCommandService
    // This functionality will need to be added when required
    func restoreSnapshot(_ snapshot: Snapshot, to path: URL) async {
        self.error = ResticError.commandError("Snapshot restoration is not currently supported")
        showError = true
    }
    
    func pruneSnapshots() async {
        do {
            // Get credentials for repository
            let credentials = try await credentialsManager.retrieve(forId: repository.id)
            
            // Create Repository with credentials
            let repoWithCredentials = Repository(
                name: repository.name,
                path: repository.path,
                credentials: credentials
            )
            
            // Prune snapshots
            try await resticService.pruneSnapshots(
                in: repoWithCredentials,
                keepLast: pruneOptions.keepLast,
                keepDaily: pruneOptions.keepDaily,
                keepWeekly: pruneOptions.keepWeekly,
                keepMonthly: pruneOptions.keepMonthly,
                keepYearly: pruneOptions.keepYearly
            )
            
            // Reload snapshots after pruning
            await loadSnapshots()
            logger.infoMessage("Successfully pruned snapshots")
        } catch {
            logger.errorMessage("Failed to prune snapshots: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
    
    var filteredSnapshots: [Snapshot] {
        let filtered = snapshots.filter { snapshot in
            // Apply search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let matchesPath = snapshot.paths.contains { $0.lowercased().contains(searchLower) }
                let matchesTag = snapshot.tags.contains { $0.lowercased().contains(searchLower) }
                let matchesHostname = snapshot.hostname.lowercased().contains(searchLower)
                let matchesUsername = snapshot.username.lowercased().contains(searchLower)
                
                if !matchesPath && !matchesTag && !matchesHostname && !matchesUsername {
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
                return !snapshot.tags.isEmpty
            }
        }
        
        return filtered
    }
    
    var groupedSnapshots: [(String, [Snapshot])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSnapshots) { snapshot in
            calendar.startOfDay(for: snapshot.time)
        }
        
        return grouped.map { (date, snapshots) in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return (formatter.string(from: date), snapshots)
        }.sorted { $0.0 > $1.0 }
    }
    
    var uniqueTags: [String] {
        Array(Set(snapshots.flatMap(\.tags))).sorted()
    }
}
