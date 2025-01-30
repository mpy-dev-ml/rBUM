//
//  RepositoryListView.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import SwiftUI

struct RepositoryListView: View {
    @StateObject private var viewModel: RepositoryListViewModel
    private let creationService: RepositoryCreationServiceProtocol
    private let resticService: ResticCommandServiceProtocol
    
    init(
        repositoryStorage: RepositoryStorageProtocol,
        creationService: RepositoryCreationServiceProtocol,
        resticService: ResticCommandServiceProtocol
    ) {
        _viewModel = StateObject(wrappedValue: RepositoryListViewModel(repositoryStorage: repositoryStorage))
        self.creationService = creationService
        self.resticService = resticService
    }
    
    var body: some View {
        NavigationSplitView {
            List {
                if viewModel.repositories.isEmpty {
                    ContentUnavailableView(
                        "No Repositories",
                        systemImage: "folder.badge.questionmark",
                        description: Text("Add a repository to get started")
                    )
                } else {
                    ForEach(viewModel.repositories) { repository in
                        NavigationLink(value: repository) {
                            RepositoryRowView(repository: repository)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteRepository(viewModel.repositories[index])
                        }
                    }
                }
            }
            .navigationTitle("Repositories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: viewModel.showCreateRepository) {
                        Label("Add Repository", systemImage: "plus")
                    }
                }
            }
        } detail: {
            NavigationStack {
                if let repository = viewModel.repositories.first {
                    RepositoryDetailView(
                        repository: repository,
                        resticService: resticService
                    )
                } else {
                    Text("Select a repository")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $viewModel.showCreationSheet) {
            NavigationStack {
                RepositoryCreationView(creationService: creationService)
                    .onChange(of: viewModel.showCreationSheet) { oldValue, newValue in
                        if !newValue {
                            // Sheet was dismissed, check for new repository
                            viewModel.loadRepositories()
                        }
                    }
            }
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
            viewModel.loadRepositories()
        }
    }
}

private struct RepositoryRowView: View {
    let repository: Repository
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(repository.name)
                .font(.headline)
            
            Text(repository.path.path())
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}
