//
//  BackupView.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import SwiftUI

struct BackupView: View {
    @StateObject private var viewModel: BackupViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(repository: Repository, resticService: ResticCommandServiceProtocol) {
        _viewModel = StateObject(wrappedValue: BackupViewModel(
            repository: repository,
            resticService: resticService
        ))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if case .backing(let progress) = viewModel.state {
                ProgressView("Creating backup...", value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .padding()
            } else if case .completed = viewModel.state {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    
                    Text("Backup Completed")
                        .font(.headline)
                }
                .padding()
            } else {
                // Path selection
                if viewModel.selectedPaths.isEmpty {
                    ContentUnavailableView(
                        "No Files Selected",
                        systemImage: "folder.badge.plus",
                        description: Text("Select files and folders to back up")
                    )
                } else {
                    List {
                        Section("Selected Items") {
                            ForEach(viewModel.selectedPaths, id: \.self) { path in
                                HStack {
                                    Image(systemName: path.hasDirectoryPath ? "folder.fill" : "doc.fill")
                                        .foregroundStyle(.secondary)
                                    
                                    Text(path.lastPathComponent)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if let resources = try? path.resourceValues(forKeys: [.fileSizeKey]),
                                       let size = resources.fileSize {
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Action buttons
                HStack {
                    Button {
                        viewModel.selectPaths()
                    } label: {
                        Label("Select Files", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    
                    if !viewModel.selectedPaths.isEmpty {
                        Button {
                            Task {
                                await viewModel.startBackup()
                            }
                        } label: {
                            Label("Start Backup", systemImage: "arrow.up.doc")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Create Backup")
        .alert("Backup Failed", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.reset()
            }
        } message: {
            if case .failed(let error) = viewModel.state {
                Text(error.localizedDescription)
            }
        }
    }
}
