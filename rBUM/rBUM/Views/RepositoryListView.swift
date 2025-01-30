//
//  RepositoryListView.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import SwiftUI

struct RepositoryListView: View {
    @StateObject private var viewModel: RepositoryListViewModel
    @State private var showAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var repositoryToDelete: Repository?
    
    init() {
        _viewModel = StateObject(wrappedValue: RepositoryListViewModel())
    }
    
    var body: some View {
        NavigationStack {
            List(viewModel.repositories) { repository in
                NavigationLink(destination: RepositoryDetailView(repository: repository)) {
                    RepositoryRowView(repository: repository)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        repositoryToDelete = repository
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Repositories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Repository", systemImage: "plus")
                    }
                }
            }
            .alert("Delete Repository", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let repository = repositoryToDelete {
                        Task {
                            await viewModel.deleteRepository(repository)
                        }
                    }
                }
            } message: {
                if let repository = repositoryToDelete {
                    Text("Are you sure you want to delete '\(repository.name)'? This action cannot be undone.")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                RepositoryCreationView(creationService: viewModel.repositoryCreationService)
                    .onChange(of: showAddSheet) { oldValue, newValue in
                        if !newValue {
                            // Sheet was dismissed, check for new repository
                            Task {
                                await viewModel.loadRepositories()
                            }
                        }
                    }
            }
            .task {
                await viewModel.loadRepositories()
            }
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

struct RepositoryListView_Previews: PreviewProvider {
    static var previews: some View {
        RepositoryListView()
    }
}
