//
//  SnapshotListView.swift
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

import SwiftUI

struct SnapshotListView: View {
    @StateObject private var viewModel: SnapshotListViewModel
    @State private var showingDeleteAlert = false
    @State private var snapshotToDelete: Snapshot?

    init(repository: Repository) {
        _viewModel = StateObject(wrappedValue: SnapshotListViewModel(
            repository: repository,
            resticService: ResticCommandService(), // Use default parameters
            credentialsManager: KeychainCredentialsManager()
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading snapshots...")
            } else if viewModel.snapshots.isEmpty {
                ContentUnavailableView(
                    "No Snapshots",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Create a backup to add snapshots")
                )
            } else if viewModel.groupedSnapshots.isEmpty {
                ContentUnavailableView(
                    "No Matching Snapshots",
                    systemImage: "magnifyingglass",
                    description: Text("Try adjusting your search or filter")
                )
                .searchable(text: $viewModel.searchText)
            } else {
                List {
                    ForEach(viewModel.groupedSnapshots, id: \.0) { date, snapshots in
                        Section(date) {
                            ForEach(snapshots) { snapshot in
                                SnapshotRowView(snapshot: snapshot)
                                    .contextMenu {
                                        Button {
                                            viewModel.selectedSnapshot = snapshot
                                            viewModel.showRestoreSheet = true
                                        } label: {
                                            Label("Restore", systemImage: "arrow.uturn.backward")
                                        }

                                        Button(role: .destructive) {
                                            snapshotToDelete = snapshot
                                            showingDeleteAlert = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .searchable(text: $viewModel.searchText)
                .refreshable {
                    await viewModel.loadSnapshots()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Filter", selection: $viewModel.selectedFilter) {
                        ForEach(SnapshotListViewModel.Filter.allCases, id: \.self) { filter in
                            Text(filter.rawValue)
                                .tag(filter)
                        }
                    }

                    Divider()

                    Button {
                        viewModel.showPruneSheet = true
                    } label: {
                        Label("Prune Snapshots", systemImage: "scissors")
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .alert("Delete Snapshot", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let snapshot = snapshotToDelete {
                    Task {
                        await viewModel.deleteSnapshot(snapshot)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this snapshot? This action cannot be undone.")
        }
        .sheet(isPresented: $viewModel.showRestoreSheet) {
            if let snapshot = viewModel.selectedSnapshot {
                RestoreSheetView(snapshot: snapshot) { path in
                    Task {
                        await viewModel.restoreSnapshot(snapshot, to: path)
                        viewModel.showRestoreSheet = false
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showPruneSheet) {
            PruneSheetView(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .task {
            await viewModel.loadSnapshots()
        }
    }
}

private struct SnapshotRowView: View {
    let snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snapshot.time, style: .time)
                    .font(.headline)

                Spacer()

                Text(snapshot.formattedSize())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(snapshot.paths.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !snapshot.tags.isEmpty {
                HStack {
                    ForEach(snapshot.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RestoreSheetView: View {
    let snapshot: Snapshot
    let onRestore: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPath: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Created: \(snapshot.time.formatted())")
                    Text("Size: \(snapshot.formattedSize())")
                    Text("Paths: \(snapshot.paths.joined(separator: ", "))")
                }

                Section("Restore Location") {
                    if let path = selectedPath {
                        Text(path.path())
                            .foregroundStyle(.secondary)
                    }

                    Button("Choose Location") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.canCreateDirectories = true

                        if panel.runModal() == .OK {
                            selectedPath = panel.url
                        }
                    }
                }
            }
            .navigationTitle("Restore Snapshot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Restore") {
                        if let path = selectedPath {
                            onRestore(path)
                        }
                    }
                    .disabled(selectedPath == nil)
                }
            }
        }
        .frame(width: 400)
    }
}

private struct PruneSheetView: View {
    @ObservedObject var viewModel: SnapshotListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Keep Most Recent") {
                    HStack {
                        Text("Last")
                        TextField("", value: $viewModel.pruneOptions.keepLast, format: .number)
                            .multilineTextAlignment(.trailing)
                        Text("snapshots")
                    }
                }

                Section("Keep Time-Based") {
                    HStack {
                        Text("Daily")
                        TextField("", value: $viewModel.pruneOptions.keepDaily, format: .number)
                            .multilineTextAlignment(.trailing)
                        Text("snapshots")
                    }

                    HStack {
                        Text("Weekly")
                        TextField("", value: $viewModel.pruneOptions.keepWeekly, format: .number)
                            .multilineTextAlignment(.trailing)
                        Text("snapshots")
                    }

                    HStack {
                        Text("Monthly")
                        TextField("", value: $viewModel.pruneOptions.keepMonthly, format: .number)
                            .multilineTextAlignment(.trailing)
                        Text("snapshots")
                    }

                    HStack {
                        Text("Yearly")
                        TextField("", value: $viewModel.pruneOptions.keepYearly, format: .number)
                            .multilineTextAlignment(.trailing)
                        Text("snapshots")
                    }
                }

                Section("Keep Tags") {
                    ForEach(viewModel.uniqueTags, id: \.self) { tag in
                        Toggle(tag, isOn: Binding(
                            get: { viewModel.pruneOptions.tags?.contains(tag) ?? false },
                            set: { isOn in
                                if isOn {
                                    viewModel.pruneOptions.tags = (viewModel.pruneOptions.tags ?? []) + [tag]
                                } else {
                                    viewModel.pruneOptions.tags?.removeAll { $0 == tag }
                                }
                            }
                        ))
                    }
                }

                Section {
                    Text("Snapshots matching any of these rules will be kept. All other snapshots will be removed.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Prune Snapshots")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Prune") {
                        Task {
                            await viewModel.pruneSnapshots()
                            dismiss()
                        }
                    }
                }
            }
        }
        .frame(width: 400)
    }
}

struct SnapshotListView_Previews: PreviewProvider {
    static var previews: some View {
        SnapshotListView(
            repository: Repository(
                name: "Test",
                path: "/tmp/test",
                credentials: RepositoryCredentials(
                    repositoryPath: "/tmp/test",
                    password: "test-password"
                )
            )
        )
    }
}
