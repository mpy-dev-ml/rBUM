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
        case tagged = "Tagged"
    }
    
    struct PruneOptions {
        var keepLast: Int?
        var keepHourly: Int?
        var keepDaily: Int?
        var keepWeekly: Int?
        var keepMonthly: Int?
        var keepYearly: Int?
        var keepTags: [String]?
    }
    
    @Published private(set) var snapshots: [Snapshot] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    @Published var selectedSnapshot: Snapshot?
    @Published var showRestoreSheet = false
    @Published var restorePath: URL?
    @Published var searchText = ""
    @Published var selectedFilter: Filter = .all
    @Published var showPruneSheet = false
    @Published var pruneOptions = PruneOptions()
    
    private let repository: Repository
    private let resticService: ResticCommandServiceProtocol
    private let logger = Logging.logger(for: .repository)
    private let calendar = Calendar.current
    
    init(repository: Repository, resticService: ResticCommandServiceProtocol) {
        self.repository = repository
        self.resticService = resticService
    }
    
    func loadSnapshots() async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            snapshots = try await resticService.listSnapshots(for: repository)
            snapshots.sort { $0.time > $1.time } // Sort by newest first
            logger.infoMessage("Loaded \(snapshots.count) snapshots")
        } catch {
            logger.errorMessage("Failed to load snapshots: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
    
    func deleteSnapshot(_ snapshot: Snapshot) async {
        do {
            try await resticService.deleteSnapshot(snapshot.id, from: repository)
            snapshots.removeAll { $0.id == snapshot.id }
            logger.infoMessage("Deleted snapshot \(snapshot.id)")
        } catch {
            logger.errorMessage("Failed to delete snapshot: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
    
    func restoreSnapshot(_ snapshot: Snapshot, to path: URL) async {
        do {
            try await resticService.restoreSnapshot(snapshot.id, from: repository, to: path)
            logger.infoMessage("Restored snapshot \(snapshot.id) to \(path.path())")
        } catch {
            logger.errorMessage("Failed to restore snapshot: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
    
    func pruneSnapshots() async {
        do {
            try await resticService.pruneSnapshots(
                for: repository,
                keepLast: pruneOptions.keepLast,
                keepHourly: pruneOptions.keepHourly,
                keepDaily: pruneOptions.keepDaily,
                keepWeekly: pruneOptions.keepWeekly,
                keepMonthly: pruneOptions.keepMonthly,
                keepYearly: pruneOptions.keepYearly,
                keepTags: pruneOptions.keepTags
            )
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
