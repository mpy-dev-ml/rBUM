import Foundation

extension SnapshotListViewModel {
    // MARK: - Filtering

    /// Filter snapshots based on selected filter and search text
    func applyFilters() {
        let filtered = repository.snapshots.filter { snapshot in
            let matchesSearch = searchText.isEmpty ||
                snapshot.id.localizedCaseInsensitiveContains(searchText) ||
                snapshot.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }

            let matchesFilter = switch selectedFilter {
            case .all:
                true
            case .today:
                Calendar.current.isDateInToday(snapshot.time)
            case .thisWeek:
                Calendar.current.isDate(snapshot.time, equalTo: Date(), toGranularity: .weekOfYear)
            case .thisMonth:
                Calendar.current.isDate(snapshot.time, equalTo: Date(), toGranularity: .month)
            case .thisYear:
                Calendar.current.isDate(snapshot.time, equalTo: Date(), toGranularity: .year)
            case .tagged:
                !snapshot.tags.isEmpty
            }

            return matchesSearch && matchesFilter
        }

        snapshots = filtered.sorted { $0.time > $1.time }
    }

    /// Reset all filters to their default values
    func resetFilters() {
        searchText = ""
        selectedFilter = .all
        applyFilters()
    }
}
