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
            if case .backing(let progress) = viewModel.state {
                VStack(spacing: 8) {
                    ProgressView(value: progress.byteProgress, total: 100) {
                        Text(viewModel.progressMessage)
                            .font(.headline)
                    }
                    .progressViewStyle(.linear)
                    
                    Text("Elapsed time: \(Int(progress.updatedAt.timeIntervalSince(progress.startTime))) seconds")
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
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    
                    Text("Select Files to Back Up")
                        .font(.headline)
                }
                .padding()
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if case .backing = viewModel.state {
                    Button("Cancel Backup") {
                        Task {
                            await viewModel.cancelBackup()
                        }
                    }
                    .buttonStyle(.bordered)
                } else if case .completed = viewModel.state {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Select Files") {
                        Task {
                            await viewModel.selectPaths()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Start Backup") {
                        Task {
                            await viewModel.startBackup()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedPaths.isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .alert("Backup Failed", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            if case .failed(let error) = viewModel.state {
                Text(error.localizedDescription)
            }
        }
    }
}

private final class PreviewResticCommandService: ResticCommandServiceProtocol {
    func listSnapshots(in repository: ResticRepository) async throws -> [ResticSnapshot] {
        return []
    }
    
    func initializeRepository(at path: URL, password: String) async throws {}
    
    func check(_ repository: ResticRepository) async throws {}
    
    func createBackup(
        paths: [URL],
        to repository: ResticRepository,
        tags: [String]? = nil,
        onProgress: ((ResticBackupProgress) -> Void)? = nil,
        onStatusChange: ((ResticBackupStatus) -> Void)? = nil
    ) async throws {
        // Simulate backup progress
        onStatusChange?(.preparing)
        
        // Simulate progress updates
        let progress = ResticBackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1024 * 1024,
            processedBytes: 512 * 1024,
            currentFile: "/test/file.txt",
            startTime: Date(),
            updatedAt: Date()
        )
        onProgress?(progress)
        onStatusChange?(.backing(progress))
        
        // Simulate completion
        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay
        onStatusChange?(.completed)
    }
    
    func pruneSnapshots(
        in repository: ResticRepository,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {}
}

private final class PreviewCredentialsManager: CredentialsManagerProtocol {
    func store(_ credentials: RepositoryCredentials) async throws {
        <#code#>
    }
    
    func retrieve(forId id: UUID) async throws -> RepositoryCredentials {
        <#code#>
    }
    
    func delete(forId id: UUID) async throws {
        <#code#>
    }
    
    func getPassword(forRepositoryId id: UUID) async throws -> String {
        <#code#>
    }
    
    func createCredentials(id: UUID, path: String, password: String) -> RepositoryCredentials {
        <#code#>
    }
    
    func getCredentials(for repository: Repository) throws -> RepositoryCredentials {
        RepositoryCredentials(
            repositoryId: repository.id,
            password: "test",
            repositoryPath: repository.path.path
        )
    }
    
    func storeCredentials(_ credentials: RepositoryCredentials) throws {}
    
    func deleteCredentials(forRepositoryId repositoryId: UUID) throws {}
}

// MARK: - Preview

#Preview {
    BackupView(repository: Repository(
        name: "Test Repository",
        path: URL(fileURLWithPath: "/test/repo")
    ))
    .frame(width: 400, height: 500)
}
