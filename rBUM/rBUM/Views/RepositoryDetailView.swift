//
//  RepositoryDetailView.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import SwiftUI

struct RepositoryDetailView: View {
    @StateObject private var viewModel: RepositoryDetailViewModel
    @State private var showPasswordSheet = false
    private let resticService: ResticCommandServiceProtocol
    private let credentialsManager: CredentialsManagerProtocol
    
    init(
        repository: Repository,
        resticService: ResticCommandServiceProtocol = ResticCommandService(
            credentialsManager: KeychainCredentialsManager(),
            processExecutor: ProcessExecutor()
        ),
        credentialsManager: CredentialsManagerProtocol = KeychainCredentialsManager()
    ) {
        _viewModel = StateObject(wrappedValue: RepositoryDetailViewModel(
            repository: repository,
            resticService: resticService,
            credentialsManager: credentialsManager
        ))
        self.resticService = resticService
        self.credentialsManager = credentialsManager
    }
    
    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            // Overview tab
            Form {
                Section("Repository Status") {
                    HStack {
                        Label {
                            Text(viewModel.isChecking ? "Checking..." : "Status")
                        } icon: {
                            if viewModel.isChecking {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(viewModel.statusColor)
                            }
                        }
                    }
                }
                
                Section("General") {
                    LabeledContent("Name", value: viewModel.repository.name)
                    LabeledContent("Path", value: viewModel.repository.path.path())
                    LabeledContent("Created", value: viewModel.repository.createdAt.formatted())
                    
                    if let lastCheck = viewModel.lastCheck {
                        LabeledContent("Last Check", value: lastCheck.formatted())
                    }
                }
            }
            .tabItem {
                Label(
                    RepositoryDetailViewModel.Tab.overview.rawValue,
                    systemImage: RepositoryDetailViewModel.Tab.overview.icon
                )
            }
            .tag(RepositoryDetailViewModel.Tab.overview)
            
            // Snapshots tab
            NavigationLink(destination: SnapshotListView(repository: viewModel.repository)) {
                Label("Snapshots", systemImage: "clock.arrow.circlepath")
            }
            .tabItem {
                Label(
                    RepositoryDetailViewModel.Tab.snapshots.rawValue,
                    systemImage: RepositoryDetailViewModel.Tab.snapshots.icon
                )
            }
            .tag(RepositoryDetailViewModel.Tab.snapshots)
            
            // Settings tab
            Text("Settings")
                .tabItem {
                    Label(
                        RepositoryDetailViewModel.Tab.settings.rawValue,
                        systemImage: RepositoryDetailViewModel.Tab.settings.icon
                    )
                }
                .tag(RepositoryDetailViewModel.Tab.settings)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: BackupView(repository: viewModel.repository)) {
                    Label("Backup", systemImage: "arrow.clockwise.circle")
                }
            }
        }
        .navigationTitle(viewModel.repository.name)
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
            await viewModel.checkRepository()
        }
    }
}

struct RepositoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RepositoryDetailView(
            repository: Repository(name: "Test", path: URL(fileURLWithPath: "/tmp/test"))
        )
    }
}
