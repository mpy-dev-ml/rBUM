//
//  RepositoryDetailView.swift
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

/// Displays detailed information and controls for a repository
struct RepositoryDetailView: View {
    @StateObject private var viewModel: RepositoryDetailViewModel
    @State private var showPasswordSheet = false
    @Environment(\.dismiss) private var dismiss

    /// Creates a view to manage a specific repository
    init(
        repository: Repository,
        resticService: ResticCommandServiceProtocol = ResticCommandService(),
        credentialsManager: KeychainCredentialsManagerProtocol = KeychainCredentialsManager()
    ) {
        _viewModel = StateObject(
            wrappedValue: RepositoryDetailViewModel(
                repository: repository,
                resticService: resticService,
                credentialsManager: credentialsManager
            )
        )
    }

    var body: some View {
        contentView
            .navigationTitle(viewModel.repository.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    backupButton
                }
            }
            .alert(
                "Error",
                isPresented: $viewModel.showError
            ) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .task {
                await viewModel.checkRepository()
            }
    }

    @ViewBuilder
    private var contentView: some View {
        TabView(selection: $viewModel.selectedTab) {
            OverviewTabView(viewModel: viewModel)
                .tabItem { tabLabel(for: .overview) }
                .tag(RepositoryDetailViewModel.Tab.overview)

            SnapshotsTabView(viewModel: viewModel)
                .tabItem { tabLabel(for: .snapshots) }
                .tag(RepositoryDetailViewModel.Tab.snapshots)

            SettingsTabView()
                .tabItem { tabLabel(for: .settings) }
                .tag(RepositoryDetailViewModel.Tab.settings)
        }
    }

    private var backupButton: some View {
        NavigationLink(
            destination: BackupView(
                repository: viewModel.repository
            )
        ) {
            Label(
                "Backup",
                systemImage: "arrow.clockwise.circle"
            )
        }
        .accessibilityLabel("Start backup")
        .accessibilityHint("Navigate to backup creation screen")
    }

    private func tabLabel(for tab: RepositoryDetailViewModel.Tab) -> some View {
        Label(
            tab.rawValue,
            systemImage: tab.icon
        )
        .labelStyle(.iconOnly)
    }
}

private struct OverviewTabView: View {
    @ObservedObject var viewModel: RepositoryDetailViewModel

    var body: some View {
        Form {
            RepositoryStatusSection(viewModel: viewModel)
            RepositoryDetailsSection(viewModel: viewModel)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct RepositoryStatusSection: View {
    @ObservedObject var viewModel: RepositoryDetailViewModel

    var body: some View {
        Section("Repository Status") {
            statusLabel
        }
    }

    private var statusLabel: some View {
        Label {
            Text(viewModel.isChecking ? "Checking..." : "Status")
        } icon: {
            statusIcon
        }
        .accessibilityLabel(viewModel.isChecking ? "Checking repository status" : "Repository status")
    }

    @ViewBuilder
    private var statusIcon: some View {
        if viewModel.isChecking {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "circle.fill")
                .foregroundStyle(viewModel.statusColor)
                .accessibilityHidden(true)
        }
    }
}

private struct RepositoryDetailsSection: View {
    @ObservedObject var viewModel: RepositoryDetailViewModel

    var body: some View {
        Section("General") {
            generalInfoGroup
            lastCheckInfo
        }
    }

    @ViewBuilder
    private var generalInfoGroup: some View {
        VStack(alignment: .leading) {
            LabeledContent<Text, Text>(
                content: { Text(viewModel.repository.name) },
                label: { Text("Name") }
            )
            .accessibilityLabel("Repository name: \(viewModel.repository.name)")

            LabeledContent<Text, Text>(
                content: { Text(viewModel.repository.path) },
                label: { Text("Path") }
            )
            .accessibilityLabel("Repository path: \(viewModel.repository.path)")

            LabeledContent<Text, Text>(
                content: { Text(viewModel.repository.createdAt.formatted(date: .abbreviated, time: .shortened)) },
                label: { Text("Created") }
            )
            .accessibilityLabel(
                "Created on \(viewModel.repository.createdAt.formatted(date: .abbreviated, time: .shortened))"
            )
        }
    }

    @ViewBuilder
    private var lastCheckInfo: some View {
        if let lastCheck = viewModel.lastCheck {
            LabeledContent<Text, Text>(
                content: { Text(lastCheck.formatted(date: .abbreviated, time: .shortened)) },
                label: { Text("Last Check") }
            )
            .accessibilityLabel("Last checked on \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
        }
    }
}

private struct SnapshotsTabView: View {
    @ObservedObject var viewModel: RepositoryDetailViewModel

    var body: some View {
        NavigationLink(destination: SnapshotListView(repository: viewModel.repository)) {
            Label("Snapshots", systemImage: "clock.arrow.circlepath")
        }
        .accessibilityLabel("View snapshots")
        .accessibilityHint("Navigate to list of repository snapshots")
    }
}

private struct SettingsTabView: View {
    var body: some View {
        Text("Settings")
            .accessibilityLabel("Repository settings")
    }
}

struct RepositoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RepositoryDetailView(
            repository: Repository(
                name: "Test Repository",
                path: "/tmp/test",
                credentials: RepositoryCredentials(
                    repositoryPath: "/tmp/test",
                    password: "test-password"
                )
            )
        )
    }
}
