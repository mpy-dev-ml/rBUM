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
    
    init(repository: Repository) {
        _viewModel = StateObject(wrappedValue: BackupViewModel(
            repository: repository,
            resticService: PreviewResticCommandService(),
            credentialsManager: PreviewCredentialsManager()
        ))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if case .inProgress(let progress) = viewModel.state {
                VStack(spacing: 8) {
                    ProgressView(value: progress.overallProgress, total: 100) {
                        Text(viewModel.progressMessage)
                            .font(.headline)
                    }
                    .progressViewStyle(.linear)
                    
                    Text(progress.formattedTimeRemaining)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(progress.formattedElapsedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

// MARK: - Preview Helpers

private final class PreviewResticCommandService: ResticCommandServiceProtocol {
    func checkRepository(_ repository: URL, withPassword password: String) async throws -> RepositoryStatus {
        // Return mock status for preview
        return RepositoryStatus(
            isValid: true,
            packsValid: true,
            indexValid: true,
            snapshotsValid: true,
            errors: [],
            stats: .init(
                totalSize: 1024 * 1024 * 100,  // 100 MB
                packFiles: 10,
                snapshots: 5
            )
        )
    }
    
    func initializeRepository(at path: URL, password: String) async throws {}
    
    func checkRepository(at path: URL, credentials: RepositoryCredentials) async throws {}
    
    func createBackup(
        paths: [URL],
        to repository: Repository,
        credentials: RepositoryCredentials,
        tags: [String]?,
        onProgress: ((BackupProgress) -> Void)?,
        onStatusChange: ((BackupStatus) -> Void)?
    ) async throws {
        // Simulate backup progress
        onStatusChange?(.preparing)
        
        // Simulate progress updates
        let progress = BackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1024 * 1024,
            processedBytes: 512 * 1024,
            currentFile: "/test/file.txt",
            estimatedSecondsRemaining: 30,
            startTime: Date()
        )
        onProgress?(progress)
        onStatusChange?(.backing(progress))
        
        // Simulate completion
        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay
        onStatusChange?(.completed)
    }
    
    func listSnapshots(in repository: Repository, credentials: RepositoryCredentials) async throws -> [Snapshot] {
        []
    }
    
    func pruneSnapshots(
        in repository: Repository,
        credentials: RepositoryCredentials,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {}
}

private final class PreviewCredentialsManager: CredentialsManagerProtocol {
    func store(_ credentials: RepositoryCredentials) async throws {}
    
    func retrieve(forId id: UUID) async throws -> RepositoryCredentials {
        createCredentials(id: id, path: "/test/repo", password: "test-password")
    }
    
    func delete(forId id: UUID) async throws {}
    
    func getPassword(forRepositoryId id: UUID) async throws -> String {
        "test-password"
    }
    
    func createCredentials(id: UUID, path: String, password: String) -> RepositoryCredentials {
        RepositoryCredentials(
            repositoryId: id,
            password: password,
            repositoryPath: path
        )
    }
}

// MARK: - Preview

#Preview {
    BackupView(repository: Repository(
        name: "Test Repository",
        path: URL(fileURLWithPath: "/test/repo")
    ))
    .frame(width: 400, height: 500)
}
