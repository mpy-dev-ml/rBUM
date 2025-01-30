//
//  RepositoryDetailView.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import SwiftUI

struct RepositoryDetailView: View {
    @StateObject private var viewModel: RepositoryDetailViewModel
    
    init(repository: Repository, resticService: ResticCommandServiceProtocol) {
        _viewModel = StateObject(wrappedValue: RepositoryDetailViewModel(
            repository: repository,
            resticService: resticService
        ))
    }
    
    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            overviewTab
                .tabItem {
                    Label(
                        RepositoryDetailViewModel.Tab.overview.rawValue,
                        systemImage: RepositoryDetailViewModel.Tab.overview.icon
                    )
                }
                .tag(RepositoryDetailViewModel.Tab.overview)
            
            Text("Snapshots")
                .tabItem {
                    Label(
                        RepositoryDetailViewModel.Tab.snapshots.rawValue,
                        systemImage: RepositoryDetailViewModel.Tab.snapshots.icon
                    )
                }
                .tag(RepositoryDetailViewModel.Tab.snapshots)
            
            Text("Settings")
                .tabItem {
                    Label(
                        RepositoryDetailViewModel.Tab.settings.rawValue,
                        systemImage: RepositoryDetailViewModel.Tab.settings.icon
                    )
                }
                .tag(RepositoryDetailViewModel.Tab.settings)
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
    }
    
    private var overviewTab: some View {
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
                    
                    Spacer()
                    
                    Button("Check Now") {
                        Task {
                            await viewModel.checkRepository()
                        }
                    }
                    .disabled(viewModel.isChecking)
                }
                
                LabeledContent("Last Check") {
                    Text(viewModel.formattedLastCheck)
                }
            }
            
            Section("Repository Details") {
                LabeledContent("Name") {
                    Text(viewModel.repository.name)
                }
                
                LabeledContent("Location") {
                    Text(viewModel.repository.path.path())
                        .textSelection(.enabled)
                }
                
                LabeledContent("ID") {
                    Text(viewModel.repository.id.uuidString)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Quick Actions") {
                Button {
                    // TODO: Implement backup
                } label: {
                    Label("Create Backup", systemImage: "arrow.clockwise")
                }
                
                Button {
                    // TODO: Implement restore
                } label: {
                    Label("Restore Files", systemImage: "arrow.uturn.backward")
                }
                
                Button {
                    // TODO: Implement prune
                } label: {
                    Label("Prune Old Snapshots", systemImage: "trash")
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}
