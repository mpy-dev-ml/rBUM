//
//  BackupView.swift
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

struct BackupView: View {
    @StateObject private var viewModel: BackupViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(repository: Repository) {
        _viewModel = StateObject(wrappedValue: BackupViewModel(
            repository: repository,
            resticService: ResticCommandService(
                fileManager: .default,
                logger: Logging.logger(for: .repository)
            ),
            credentialsManager: KeychainCredentialsManager()
        ))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if case .backing = viewModel.state, let progress = viewModel.currentProgress {
                VStack(spacing: 8) {
                    ProgressView(value: progress.percentComplete, total: 100) {
                        Text(viewModel.progressMessage)
                            .font(.headline)
                    }
                    .progressViewStyle(.linear)
                    
                    HStack {
                        Text("\(progress.processedFiles)/\(progress.totalFiles) files")
                        Spacer()
                        Text("\(Int(progress.percentComplete))%")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                Text(viewModel.progressMessage)
                    .font(.headline)
                    .padding()
            }
            
            if viewModel.selectedPaths.isEmpty {
                Button("Select Files") {
                    Task {
                        await viewModel.selectPaths()
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.selectedPaths, id: \.absoluteString) { path in
                        HStack {
                            Image(systemName: "doc.fill")
                            Text(path.lastPathComponent)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                
                HStack(spacing: 20) {
                    Button("Start Backup") {
                        Task {
                            await viewModel.startBackup()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.state.isActive)
                    
                    if viewModel.state.isActive {
                        Button("Cancel") {
                            Task {
                                await viewModel.cancelBackup()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .frame(width: 400)
        .padding()
        .alert("Backup Failed", isPresented: $viewModel.showError) {
            Button("OK") {
                dismiss()
            }
        } message: {
            if case .failed(let error) = viewModel.state {
                Text(error.localizedDescription)
            }
        }
    }
}

private final class PreviewResticCommandService: ResticCommandServiceProtocol {
    func initRepository(credentials: RepositoryCredentials) async throws {
        // No-op for preview
    }
    
    func checkRepository(credentials: RepositoryCredentials) async throws {
        // No-op for preview
    }
    
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        // Return empty list for preview
        return []
    }
    
    func createBackup(
        paths: [URL],
        to repository: Repository,
        tags: [String]?,
        onProgress: ((ResticBackupProgress) -> Void)?,
        onStatusChange: ((ResticBackupStatus) -> Void)?
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
        in repository: Repository,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {
        // No-op for preview
    }
    
    func check(_ repository: Repository) async throws {
        // No-op for preview
    }
    
    func initializeRepository(at path: URL, password: String) async throws {
        // No-op for preview
    }
}

private final class PreviewCredentialsManager: KeychainCredentialsManagerProtocol {
    func store(_ credentials: RepositoryCredentials, forRepositoryId id: String) async throws {
        // No-op for preview
    }
    
    func retrieve(forId id: String) async throws -> RepositoryCredentials {
        // Return mock credentials for preview
        return RepositoryCredentials(
            repositoryPath: "/preview/repository",
            password: "preview"
        )
    }
    
    func delete(forId id: String) async throws {
        // No-op for preview
    }
    
    func list() async throws -> [(repositoryId: String, credentials: RepositoryCredentials)] {
        // Return empty list for preview
        return []
    }
}

// MARK: - Preview

#Preview {
    BackupView(repository: Repository(
        name: "Test Repository",
        path: "/test/repo",
        credentials: RepositoryCredentials(
            repositoryPath: "/test/repo",
            password: "test-password"
        )
    ))
    .frame(width: 400, height: 500)
}
