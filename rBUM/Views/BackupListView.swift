//
//  BackupListView.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 8 February 2025
//

import Core
import SwiftUI

/// View for displaying and managing backup operations across all repositories
struct BackupListView: View {
    /// View model managing the backup operations
    @StateObject private var viewModel: BackupListViewModel
    
    /// Initialize the backup list view
    init() {
        let logger = Logger(subsystem: "dev.mpy.rBUM", category: "backup-list")
        
        // Initialize services
        let backupService = BackupService(logger: logger)
        let repositoryService = RepositoryService(logger: logger)
        
        // Initialize view model
        _viewModel = StateObject(
            wrappedValue: BackupListViewModel(
                backupService: backupService,
                repositoryService: repositoryService,
                logger: logger
            )
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(BackupListViewModel.Filter.allCases, id: \.rawValue) { filter in
                        Text(filter.rawValue)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 400)
                
                Spacer()
                
                Button("New Backup") {
                    viewModel.showNewBackupSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search backups...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.textBackgroundColor))
            
            // Backup list
            List(viewModel.backupOperations) { operation in
                BackupOperationRow(operation: operation)
                    .contextMenu {
                        if case .inProgress = operation.state {
                            Button("Cancel Backup") {
                                Task {
                                    await viewModel.cancelBackup(operation)
                                }
                            }
                        }
                    }
            }
            .listStyle(.inset)
        }
        .sheet(isPresented: $viewModel.showNewBackupSheet) {
            NewBackupSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadBackupOperations()
        }
    }
}

/// Row view for displaying a backup operation
private struct BackupOperationRow: View {
    let operation: BackupListViewModel.BackupOperation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title and status
            HStack {
                Text(operation.repository.name)
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(state: operation.state)
            }
            
            // Sources
            Text(operation.sources.map(\.lastPathComponent).joined(separator: ", "))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Tags
            if !operation.tags.isEmpty {
                HStack {
                    ForEach(operation.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Progress or completion time
            switch operation.state {
            case .inProgress(let progress):
                ProgressView(value: progress) {
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                }
                .progressViewStyle(.linear)
                
            case .completed(let date):
                Text("Completed \(date.formatted(.relative))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .failed(let error):
                Text("Failed: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.red)
                
            case .idle:
                Text("Waiting to start...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Badge showing the backup operation status
private struct StatusBadge: View {
    let state: BackupListViewModel.BackupState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(text)
                .font(.caption)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var color: Color {
        switch state {
        case .idle:
            return .secondary
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var text: String {
        switch state {
        case .idle:
            return "Waiting"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}

/// Sheet for creating a new backup
private struct NewBackupSheet: View {
    @ObservedObject var viewModel: BackupListViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRepository: Repository?
    @State private var selectedSources: [URL] = []
    @State private var tags: String = ""
    @State private var showSourcePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Repository selection
                Section("Repository") {
                    Picker("Select Repository", selection: $selectedRepository) {
                        Text("Select a Repository")
                            .tag(Optional<Repository>.none)
                        
                        ForEach(viewModel.repositories) { repository in
                            Text(repository.name)
                                .tag(Optional(repository))
                        }
                    }
                }
                
                // Source selection
                Section("Sources") {
                    ForEach(selectedSources, id: \.self) { source in
                        HStack {
                            Text(source.lastPathComponent)
                            
                            Spacer()
                            
                            Button {
                                selectedSources.removeAll { $0 == source }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Button("Add Source") {
                        showSourcePicker = true
                    }
                }
                
                // Tags
                Section("Tags") {
                    TextField("Enter tags separated by commas", text: $tags)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .navigationTitle("New Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Backup") {
                        startBackup()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .fileImporter(
            isPresented: $showSourcePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                selectedSources.append(contentsOf: urls)
            case .failure(let error):
                print("Error selecting sources: \(error.localizedDescription)")
            }
        }
    }
    
    private var isValid: Bool {
        selectedRepository != nil && !selectedSources.isEmpty
    }
    
    private func startBackup() {
        guard let repository = selectedRepository else { return }
        
        Task {
            await viewModel.startBackup(
                to: repository,
                sources: selectedSources,
                tags: tags.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )
        }
        
        dismiss()
    }
}

#Preview {
    BackupListView()
}
